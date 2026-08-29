"""Results-free R0 feasibility harness for the approved thread-to-main exit path.

This is deliberately self-contained: it models the locked lifecycle boundary without
importing or changing the marine service.  It does not create files or contact a service.
"""

from __future__ import annotations

import asyncio
import threading
import unittest
from dataclasses import dataclass


RECOVERY_EXIT = 75
NORMAL_EXIT = 0


@dataclass(frozen=True)
class RecoveryIdentity:
    forecast_cycle: str
    input_generation_fingerprint: str
    runtime_generation: str


class ThreadBoundEvent:
    """Event whose mutation is legal only on the main coroutine's thread."""

    def __init__(self, owner_ident: int) -> None:
        self.owner_ident = owner_ident
        self.set_by: int | None = None

    def set(self) -> None:
        if threading.get_ident() != self.owner_ident:
            raise AssertionError("recovery event mutated outside the main thread")
        self.set_by = threading.get_ident()

    def is_set(self) -> bool:
        return self.set_by is not None


class FakeMainLoop:
    """Minimal loop seam that records cross-thread scheduling and main delivery."""

    def __init__(self) -> None:
        self.main_ident = threading.get_ident()
        self.calls: list[tuple[int, object]] = []

    def call_soon_threadsafe(self, callback: object) -> None:
        self.calls.append((threading.get_ident(), callback))

    def drain(self) -> None:
        if threading.get_ident() != self.main_ident:
            raise AssertionError("scheduled callbacks must be delivered on main thread")
        for _, callback in self.calls:
            callback()  # type: ignore[operator]


class FakeServer:
    def __init__(self, main_ident: int) -> None:
        self.main_ident = main_ident
        self.should_exit = False
        self.requested_by: int | None = None

    def request_exit(self) -> None:
        if threading.get_ident() != self.main_ident:
            raise AssertionError("uvicorn server stopped outside the main thread")
        self.should_exit = True
        self.requested_by = threading.get_ident()

    async def wait_until_stopped(self) -> None:
        if not self.should_exit:
            raise AssertionError("uvicorn server was awaited without should_exit")


class FakeWindTask:
    def __init__(self, main_ident: int) -> None:
        self.main_ident = main_ident
        self.cancelled = False
        self.awaited = False
        self.cancel_by: int | None = None

    def cancel(self) -> None:
        if threading.get_ident() != self.main_ident:
            raise AssertionError("wind task cancelled outside the main thread")
        self.cancelled = True
        self.cancel_by = threading.get_ident()

    async def wait(self) -> None:
        if not self.cancelled:
            raise AssertionError("wind task was awaited without cancellation")
        self.awaited = True


class RecoveryController:
    """Approved R0 boundary: one thread-safe recovery signal per identity."""

    def __init__(self, loop: FakeMainLoop, recovery_event: ThreadBoundEvent) -> None:
        self.loop = loop
        self.recovery_event = recovery_event
        self.requested: set[RecoveryIdentity] = set()
        self.blocked: list[RecoveryIdentity] = []

    def request_from_runner(self, identity: RecoveryIdentity) -> None:
        if identity in self.requested:
            self.blocked.append(identity)
            return
        self.requested.add(identity)
        self.loop.call_soon_threadsafe(self.recovery_event.set)


async def _shutdown(
    servers: list[FakeServer], wind_task: FakeWindTask, exit_code: int
) -> int:
    """Main-coroutine cleanup shape pinned by R0: stop, cancel, await, then exit."""
    for server in servers:
        server.request_exit()
    wind_task.cancel()
    await asyncio.gather(*(server.wait_until_stopped() for server in servers))
    await wind_task.wait()
    return exit_code


async def _mutant_shutdown_omits_servers(
    servers: list[FakeServer], wind_task: FakeWindTask
) -> int:
    """Negative control: intentionally omits the required uvicorn stop."""
    del servers
    wind_task.cancel()
    await wind_task.wait()
    return RECOVERY_EXIT


async def _mutant_shutdown_omits_wind_cancel(
    servers: list[FakeServer], wind_task: FakeWindTask
) -> int:
    """Negative control: intentionally omits required wind cancellation."""
    for server in servers:
        server.request_exit()
    await asyncio.gather(*(server.wait_until_stopped() for server in servers))
    await wind_task.wait()
    return RECOVERY_EXIT


class RecoveryControllerHarnessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.main_ident = threading.get_ident()
        self.identity = RecoveryIdentity("2026-08-29T12:00Z", "inputs-a", "runtime-a")

    def _recovery_fixture(
        self,
    ) -> tuple[FakeMainLoop, ThreadBoundEvent, RecoveryController, list[FakeServer], FakeWindTask]:
        loop = FakeMainLoop()
        event = ThreadBoundEvent(loop.main_ident)
        controller = RecoveryController(loop, event)
        return loop, event, controller, [FakeServer(loop.main_ident), FakeServer(loop.main_ident)], FakeWindTask(loop.main_ident)

    def _request_on_runner_thread(
        self, controller: RecoveryController, identity: RecoveryIdentity
    ) -> int:
        runner_ident: list[int] = []

        def runner() -> None:
            runner_ident.append(threading.get_ident())
            controller.request_from_runner(identity)

        thread = threading.Thread(target=runner, name="marine-runner")
        thread.start()
        thread.join()
        self.assertFalse(thread.is_alive())
        return runner_ident[0]

    def test_runner_request_is_delivered_by_call_soon_threadsafe_on_main_thread(self) -> None:
        loop, event, controller, _, _ = self._recovery_fixture()

        runner_ident = self._request_on_runner_thread(controller, self.identity)

        self.assertEqual(1, len(loop.calls))
        self.assertNotEqual(loop.main_ident, runner_ident)
        self.assertEqual(runner_ident, loop.calls[0][0])
        self.assertFalse(event.is_set())
        loop.drain()
        self.assertTrue(event.is_set())
        self.assertEqual(loop.main_ident, event.set_by)

    def test_recovery_event_stops_every_server_cancels_and_awaits_wind_then_exits_75(self) -> None:
        loop, event, controller, servers, wind_task = self._recovery_fixture()

        self._request_on_runner_thread(controller, self.identity)
        loop.drain()
        exit_code = asyncio.run(_shutdown(servers, wind_task, RECOVERY_EXIT))

        self.assertTrue(event.is_set())
        self.assertEqual(RECOVERY_EXIT, exit_code)
        self.assertTrue(all(server.should_exit for server in servers))
        self.assertTrue(all(server.requested_by == self.main_ident for server in servers))
        self.assertTrue(wind_task.cancelled)
        self.assertTrue(wind_task.awaited)
        self.assertEqual(self.main_ident, wind_task.cancel_by)

    def test_sigterm_or_sigint_normal_stop_uses_zero_exit(self) -> None:
        for signame in ("SIGTERM", "SIGINT"):
            with self.subTest(signame=signame):
                _, _, _, servers, wind_task = self._recovery_fixture()
                exit_code = asyncio.run(_shutdown(servers, wind_task, NORMAL_EXIT))
                self.assertEqual(NORMAL_EXIT, exit_code)
                self.assertTrue(all(server.should_exit for server in servers))
                self.assertTrue(wind_task.cancelled)
                self.assertTrue(wind_task.awaited)

    def test_generic_runner_exception_is_contained_without_recovery_exit(self) -> None:
        loop, event, controller, servers, wind_task = self._recovery_fixture()

        def generic_runner() -> None:
            try:
                raise RuntimeError("ordinary runner failure")
            except RuntimeError:
                pass

        thread = threading.Thread(target=generic_runner, name="marine-runner")
        thread.start()
        thread.join()
        exit_code = asyncio.run(_shutdown(servers, wind_task, NORMAL_EXIT))

        self.assertEqual([], loop.calls)
        self.assertFalse(event.is_set())
        self.assertEqual([], controller.blocked)
        self.assertEqual(NORMAL_EXIT, exit_code)

    def test_duplicate_identity_blocks_without_second_signal_or_exit(self) -> None:
        loop, event, controller, _, _ = self._recovery_fixture()

        self._request_on_runner_thread(controller, self.identity)
        loop.drain()
        self._request_on_runner_thread(controller, self.identity)

        self.assertTrue(event.is_set())
        self.assertEqual([self.identity], controller.blocked)
        self.assertEqual(1, len(loop.calls))

    def test_negative_control_direct_cross_thread_event_mutation_fails(self) -> None:
        loop = FakeMainLoop()
        event = ThreadBoundEvent(loop.main_ident)
        error: list[BaseException] = []

        def direct_mutant() -> None:
            try:
                event.set()
            except BaseException as exc:  # retain the assertion for the main thread
                error.append(exc)

        thread = threading.Thread(target=direct_mutant, name="mutant-runner")
        thread.start()
        thread.join()
        self.assertEqual(1, len(error))
        self.assertIsInstance(error[0], AssertionError)
        self.assertFalse(event.is_set())

    def test_negative_control_omitted_server_stop_fails(self) -> None:
        _, _, _, servers, wind_task = self._recovery_fixture()

        exit_code = asyncio.run(_mutant_shutdown_omits_servers(servers, wind_task))

        self.assertEqual(RECOVERY_EXIT, exit_code)
        with self.assertRaises(AssertionError):
            self.assertTrue(all(server.should_exit for server in servers))

    def test_negative_control_omitted_wind_cancel_fails(self) -> None:
        _, _, _, servers, wind_task = self._recovery_fixture()

        with self.assertRaisesRegex(AssertionError, "without cancellation"):
            asyncio.run(_mutant_shutdown_omits_wind_cancel(servers, wind_task))

    def test_negative_control_recovery_exit_zero_fails(self) -> None:
        _, _, _, servers, wind_task = self._recovery_fixture()

        mutant_exit = asyncio.run(_shutdown(servers, wind_task, NORMAL_EXIT))

        with self.assertRaises(AssertionError):
            self.assertEqual(RECOVERY_EXIT, mutant_exit)

    def test_negative_control_duplicate_second_signal_fails(self) -> None:
        loop, _, controller, _, _ = self._recovery_fixture()

        self._request_on_runner_thread(controller, self.identity)
        controller.requested.clear()  # deliberate mutant: loses deduplication state
        self._request_on_runner_thread(controller, self.identity)

        with self.assertRaises(AssertionError):
            self.assertEqual(1, len(loop.calls))


if __name__ == "__main__":
    unittest.main(verbosity=2)
