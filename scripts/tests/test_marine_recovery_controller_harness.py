"""Results-free R0 feasibility harness for the approved thread-to-main exit path.

This standard-library harness uses a running asyncio loop. It models the locked
lifecycle boundary without importing or changing the marine service.
"""

from __future__ import annotations

import asyncio
import threading
import unittest
from dataclasses import dataclass
from typing import Callable


RECOVERY_EXIT = 75
NORMAL_EXIT = 0


@dataclass(frozen=True)
class RecoveryIdentity:
    forecast_cycle: str
    input_generation_fingerprint: str
    runtime_generation: str


class ThreadBoundAsyncEvent:
    """An asyncio event which may be mutated only by its owning loop thread."""

    def __init__(self) -> None:
        self.owner_ident = threading.get_ident()
        self.event = asyncio.Event()
        self.set_by: int | None = None

    def set(self) -> None:
        if threading.get_ident() != self.owner_ident:
            raise AssertionError("event mutated outside the main loop thread")
        self.set_by = threading.get_ident()
        self.event.set()

    async def wait(self) -> None:
        await self.event.wait()

    def is_set(self) -> bool:
        return self.event.is_set()


class FakeServer:
    """Uvicorn-shaped server: should_exit is requested, then completion awaited."""

    def __init__(self, owner_ident: int) -> None:
        self.owner_ident = owner_ident
        self.should_exit = False
        self.requested_by: int | None = None
        self.awaited = False
        self.completed = False
        self._completion = asyncio.Event()

    def request_exit(self) -> None:
        if threading.get_ident() != self.owner_ident:
            raise AssertionError("uvicorn server stopped outside the main loop thread")
        self.should_exit = True
        self.requested_by = threading.get_ident()
        self._completion.set()

    async def wait_completed(self) -> None:
        await self._completion.wait()
        self.awaited = True
        self.completed = self._completion.is_set()


class FakeWindTask:
    def __init__(self, owner_ident: int) -> None:
        self.owner_ident = owner_ident
        self.cancelled = False
        self.awaited = False
        self.completed = False
        self.cancel_by: int | None = None
        self._completion = asyncio.Event()

    def cancel(self) -> None:
        if threading.get_ident() != self.owner_ident:
            raise AssertionError("wind task cancelled outside the main loop thread")
        self.cancelled = True
        self.cancel_by = threading.get_ident()
        self._completion.set()

    async def wait_completed(self) -> None:
        if not self.cancelled:
            raise AssertionError("wind task was awaited without cancellation")
        await self._completion.wait()
        self.awaited = True
        self.completed = self._completion.is_set()


class RecoveryRequested(Exception):
    """Named runner outcome that is allowed to request the recovery exit."""


class RecoveryController:
    """Approved R0 boundary: one real thread-safe signal per identity."""

    def __init__(self, loop: asyncio.AbstractEventLoop) -> None:
        self.loop = loop
        self.recovery_event = ThreadBoundAsyncEvent()
        self.operator_event = ThreadBoundAsyncEvent()
        self.requested: set[RecoveryIdentity] = set()
        self.blocked: list[RecoveryIdentity] = []
        self.recovery_posts = 0
        self.generic_runner_errors: list[str] = []

    def request_from_runner(self, identity: RecoveryIdentity) -> None:
        if identity in self.requested:
            self.blocked.append(identity)
            return
        self.requested.add(identity)
        self.recovery_posts += 1
        self.loop.call_soon_threadsafe(self.recovery_event.set)

    def dispatch_operator_signal(self, signame: str) -> None:
        if signame not in {"SIGTERM", "SIGINT"}:
            raise AssertionError(f"unexpected operator signal: {signame}")
        self.operator_event.set()

    async def serve_until_stop(
        self, servers: list[FakeServer], wind_task: FakeWindTask
    ) -> int:
        recovery_wait = asyncio.create_task(self.recovery_event.wait())
        operator_wait = asyncio.create_task(self.operator_event.wait())
        _, pending = await asyncio.wait(
            {recovery_wait, operator_wait}, return_when=asyncio.FIRST_COMPLETED
        )
        recovery = recovery_wait.done()
        for task in pending:
            task.cancel()
        await asyncio.gather(*pending, return_exceptions=True)

        for server in servers:
            server.request_exit()
        wind_task.cancel()
        await asyncio.gather(*(server.wait_completed() for server in servers))
        await wind_task.wait_completed()
        return RECOVERY_EXIT if recovery else NORMAL_EXIT


def runner_boundary(
    controller: RecoveryController,
    identity: RecoveryIdentity,
    operation: Callable[[], None],
) -> None:
    """Runner boundary: named recovery posts; generic errors remain contained."""
    try:
        operation()
    except RecoveryRequested:
        controller.request_from_runner(identity)
    except Exception as exc:
        controller.generic_runner_errors.append(type(exc).__name__)


async def _mutant_omits_server_gather(
    servers: list[FakeServer], wind_task: FakeWindTask
) -> int:
    """Negative control: cleanup requests exit but omits server completion await."""
    for server in servers:
        server.request_exit()
    wind_task.cancel()
    await wind_task.wait_completed()
    return RECOVERY_EXIT


async def _mutant_omits_wind_cancel(
    servers: list[FakeServer], wind_task: FakeWindTask
) -> int:
    """Negative control: cleanup awaits wind completion without cancelling it."""
    for server in servers:
        server.request_exit()
    await asyncio.gather(*(server.wait_completed() for server in servers))
    await wind_task.wait_completed()
    return RECOVERY_EXIT


class RecoveryControllerHarnessTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.main_ident = threading.get_ident()
        self.loop = asyncio.get_running_loop()
        self.identity = RecoveryIdentity("2026-08-29T12:00Z", "inputs-a", "runtime-a")

    def _fixture(
        self,
    ) -> tuple[RecoveryController, list[FakeServer], FakeWindTask]:
        controller = RecoveryController(self.loop)
        servers = [FakeServer(self.main_ident), FakeServer(self.main_ident)]
        return controller, servers, FakeWindTask(self.main_ident)

    async def _run_runner(
        self, controller: RecoveryController, operation: Callable[[], None]
    ) -> int:
        runner_ident: list[int] = []

        def runner() -> None:
            runner_ident.append(threading.get_ident())
            runner_boundary(controller, self.identity, operation)

        thread = threading.Thread(target=runner, name="marine-runner")
        thread.start()
        await asyncio.to_thread(thread.join)
        self.assertFalse(thread.is_alive())
        return runner_ident[0]

    def _assert_cleaned(self, servers: list[FakeServer], wind_task: FakeWindTask) -> None:
        self.assertTrue(all(server.should_exit for server in servers))
        self.assertTrue(all(server.awaited and server.completed for server in servers))
        self.assertTrue(all(server.requested_by == self.main_ident for server in servers))
        self.assertTrue(wind_task.cancelled)
        self.assertTrue(wind_task.awaited)
        self.assertTrue(wind_task.completed)
        self.assertEqual(self.main_ident, wind_task.cancel_by)

    async def test_runner_request_uses_actual_call_soon_threadsafe_and_main_exits_75(self) -> None:
        controller, servers, wind_task = self._fixture()
        main_task = asyncio.create_task(controller.serve_until_stop(servers, wind_task))
        await asyncio.sleep(0)

        runner_ident = await self._run_runner(
            controller, lambda: (_ for _ in ()).throw(RecoveryRequested())
        )
        exit_code = await main_task

        self.assertNotEqual(self.main_ident, runner_ident)
        self.assertTrue(controller.recovery_event.is_set())
        self.assertEqual(self.main_ident, controller.recovery_event.set_by)
        self.assertEqual(1, controller.recovery_posts)
        self.assertEqual(RECOVERY_EXIT, exit_code)
        self._assert_cleaned(servers, wind_task)

    async def test_sigterm_or_sigint_dispatch_wakes_main_and_exits_zero(self) -> None:
        for signame in ("SIGTERM", "SIGINT"):
            with self.subTest(signame=signame):
                controller, servers, wind_task = self._fixture()
                main_task = asyncio.create_task(controller.serve_until_stop(servers, wind_task))
                await asyncio.sleep(0)
                self.loop.call_soon(controller.dispatch_operator_signal, signame)
                exit_code = await main_task
                self.assertTrue(controller.operator_event.is_set())
                self.assertEqual(self.main_ident, controller.operator_event.set_by)
                self.assertEqual(NORMAL_EXIT, exit_code)
                self._assert_cleaned(servers, wind_task)

    async def test_generic_runner_exception_stays_waiting_until_operator_stop(self) -> None:
        controller, servers, wind_task = self._fixture()
        main_task = asyncio.create_task(controller.serve_until_stop(servers, wind_task))
        await asyncio.sleep(0)

        await self._run_runner(
            controller, lambda: (_ for _ in ()).throw(RuntimeError("ordinary runner failure"))
        )
        await asyncio.sleep(0)
        self.assertFalse(main_task.done())
        self.assertFalse(controller.recovery_event.is_set())
        self.assertEqual(["RuntimeError"], controller.generic_runner_errors)

        self.loop.call_soon(controller.dispatch_operator_signal, "SIGTERM")
        self.assertEqual(NORMAL_EXIT, await main_task)
        self._assert_cleaned(servers, wind_task)

    async def test_duplicate_identity_blocks_without_second_signal_or_exit(self) -> None:
        controller, _, _ = self._fixture()

        await self._run_runner(controller, lambda: (_ for _ in ()).throw(RecoveryRequested()))
        await asyncio.sleep(0)
        await self._run_runner(controller, lambda: (_ for _ in ()).throw(RecoveryRequested()))
        await asyncio.sleep(0)

        self.assertTrue(controller.recovery_event.is_set())
        self.assertEqual([self.identity], controller.blocked)
        self.assertEqual({self.identity}, controller.requested)
        self.assertEqual(1, controller.recovery_posts)

    async def test_negative_control_direct_cross_thread_event_mutation_fails(self) -> None:
        controller, _, _ = self._fixture()
        errors: list[BaseException] = []

        def direct_mutant() -> None:
            try:
                controller.recovery_event.set()
            except AssertionError as exc:
                errors.append(exc)

        thread = threading.Thread(target=direct_mutant, name="mutant-runner")
        thread.start()
        await asyncio.to_thread(thread.join)
        self.assertEqual(1, len(errors))
        self.assertIsInstance(errors[0], AssertionError)
        self.assertFalse(controller.recovery_event.is_set())

    async def test_negative_control_omitted_server_gather_fails(self) -> None:
        _, servers, wind_task = self._fixture()

        self.assertEqual(RECOVERY_EXIT, await _mutant_omits_server_gather(servers, wind_task))
        with self.assertRaises(AssertionError):
            self.assertTrue(all(server.awaited and server.completed for server in servers))

    async def test_negative_control_omitted_wind_cancel_fails(self) -> None:
        _, servers, wind_task = self._fixture()

        with self.assertRaisesRegex(AssertionError, "without cancellation"):
            await _mutant_omits_wind_cancel(servers, wind_task)

    async def test_negative_control_recovery_exit_zero_fails(self) -> None:
        controller, servers, wind_task = self._fixture()
        main_task = asyncio.create_task(controller.serve_until_stop(servers, wind_task))
        await asyncio.sleep(0)
        await self._run_runner(controller, lambda: (_ for _ in ()).throw(RecoveryRequested()))

        mutant_exit = await main_task
        with self.assertRaises(AssertionError):
            self.assertEqual(NORMAL_EXIT, mutant_exit)

    async def test_negative_control_duplicate_second_signal_fails(self) -> None:
        controller, _, _ = self._fixture()

        await self._run_runner(controller, lambda: (_ for _ in ()).throw(RecoveryRequested()))
        await asyncio.sleep(0)
        controller.requested.clear()  # deliberate mutant: loses deduplication state
        await self._run_runner(controller, lambda: (_ for _ in ()).throw(RecoveryRequested()))
        await asyncio.sleep(0)

        with self.assertRaises(AssertionError):
            self.assertEqual(1, controller.recovery_posts)


if __name__ == "__main__":
    unittest.main(verbosity=2)
