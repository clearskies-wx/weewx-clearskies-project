#!/usr/bin/env bash
# run-marine-tests.sh -- reserve the marine runner, then execute live pytest.
#
# One remote process owns the sentinel and its advisory lock for the complete
# wait-and-test lifecycle.  Its EXIT/signal trap stops the test child before it
# releases the hold, so a model can never resume alongside an interrupted test.

set -euo pipefail

SERVICE="weewx-clearskies-marine"
PORT=8780
REPO_PATH="/home/ubuntu/repos/weewx-clearskies-marine"
PYTHON_PATH="${REPO_PATH}/.venv/bin/python"
HOLD_PATH="/run/weewx-clearskies/marine-test-hold"
WAIT_POLL_S=60
WAIT_CEILING_S=23400
HOLD_OWNER_TOKEN="marine-tests-$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
ACTIVE_SSH_PID=""
REMOTE_STATUS=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSH_CONFIG="${PROJECT_ROOT}/.local/ssh/config"
SSH=(ssh -F "${SSH_CONFIG}")

usage() {
    echo "Usage: $0 <tests/pytest-selector> [<tests/pytest-selector> ...]" >&2
    echo "       $0 --release" >&2
    echo "Example: $0 tests/test_r8b_serving_truth.py::test_selected_full_cache_reports_valid_serving_identity" >&2
}

if [ ! -f "${SSH_CONFIG}" ]; then
    echo "SSH config not found at ${SSH_CONFIG}" >&2
    exit 1
fi
release_only="0"
if [ "$#" -eq 1 ] && [ "$1" = "--release" ]; then
    release_only="1"
elif [ "$#" -eq 0 ]; then
    usage
    exit 2
fi

# Selectors are a narrow argument vector, never a remote shell fragment.
if [ "${release_only}" = "0" ]; then
    for selector in "$@"; do
        if [[ ! "${selector}" =~ ^[A-Za-z0-9_./:\[\]=,-]+$ ]] \
            || [[ "${selector}" != tests/* ]] \
            || [[ "${selector}" == ../* || "${selector}" == */../* || "${selector}" == */.. ]]; then
            echo "Unsafe pytest selector: ${selector}" >&2
            exit 2
        fi
    done
fi

verify_librewxr_fqdn() {
    local configured_host
    configured_host=$("${SSH[@]}" -G librewxr 2>/dev/null | awk '$1 == "hostname" { print $2; exit }') || {
        echo "Could not read SSH configuration for librewxr" >&2
        return 1
    }
    if [ "${configured_host}" != "librewxr.shaneburkhardt.com" ]; then
        echo "librewxr SSH alias resolves to '${configured_host:-missing}', expected librewxr.shaneburkhardt.com" >&2
        return 1
    fi
}

# The same non-blocking lock used by acquisition makes manual stale-hold
# cleanup incapable of removing a live wrapper's sentinel.
release_hold_unconditionally() {
    local release_script remote_command
    release_script="rm -f -- '${HOLD_PATH}'"
    printf -v remote_command \
        "sudo -- flock --exclusive --nonblock --conflict-exit-code 75 %q bash -lc %q" \
        "${HOLD_PATH}" "${release_script}"
    "${SSH[@]}" -o ConnectTimeout=20 librewxr "${remote_command}"
}

cleanup() {
    local original_status=$? release_status=0
    trap - EXIT
    # A remote status of 75 means another wrapper already owns the hold.  It
    # is the only path on which this process must not attempt stale cleanup.
    if [ "${REMOTE_STATUS}" != "75" ]; then
        if release_hold_unconditionally; then
            release_status=0
        else
            release_status=$?
        fi
        if [ "${release_status}" -ne 0 ] && [ "${release_status}" -ne 75 ]; then
            echo "ERROR: could not confirm release of marine test hold ${HOLD_PATH}; manual release is required" >&2
            if [ "${original_status}" -eq 0 ]; then
                original_status=1
            fi
        fi
    fi
    exit "${original_status}"
}

handle_signal() {
    local signal_status="$1" job_pid
    # Bash records an asynchronous child in its job table before the next
    # command.  This closes the signal window between `ssh ... &` and `$!`.
    for job_pid in $(jobs -pr); do
        kill -TERM "${job_pid}" 2>/dev/null || true
    done
    for job_pid in $(jobs -pr); do
        wait "${job_pid}" 2>/dev/null || true
    done
    ACTIVE_SSH_PID=""
    exit "${signal_status}"
}

build_remote_test_command() {
    local pytest_command remote_script remote_command selector
    pytest_command="cd '${REPO_PATH}' && exec '${PYTHON_PATH}' -m pytest"
    for selector in "$@"; do
        pytest_command+=" '${selector}'"
    done

    read -r -d '' remote_script <<'REMOTE_SCRIPT' || true
set -euo pipefail
service="$1"
port="$2"
hold_path="$3"
wait_poll_s="$4"
wait_ceiling_s="$5"
owner_token="$6"
pytest_command="$7"

terminate_test() {
    local job_pid
    for job_pid in $(jobs -pr); do
        kill -TERM "${job_pid}" 2>/dev/null || true
    done
    for job_pid in $(jobs -pr); do
        wait "${job_pid}" 2>/dev/null || true
    done
}

cleanup_remote() {
    local original_status=$?
    trap - EXIT HUP INT TERM
    terminate_test
    if ! rm -f -- "${hold_path}"; then
        echo "ERROR: remote cleanup could not remove ${hold_path}" >&2
        original_status=1
    fi
    exit "${original_status}"
}

handle_remote_signal() {
    terminate_test
    exit "$1"
}

hold_health_state() {
    local probe_seconds="$1"
    curl -sk --max-time "${probe_seconds}" \
        "https://librewxr.shaneburkhardt.com:${port}/health" | python3 -c '
import json, sys
data = json.load(sys.stdin)
hold = data.get("modelTestHold")
horizon = data.get("ww3Horizon")
ready = (
    isinstance(hold, dict)
    and hold.get("requested") is True
    and hold.get("acknowledged") is True
    and data.get("run_in_progress") is False
    and isinstance(horizon, dict)
    and horizon.get("inFlight") is False
)
print("ready" if ready else "waiting")
'
}

no_model_descendants() {
    local deadline="$1" remaining probe_seconds main_pid control_group
    local cgroup_root cgroup_file pid
    remaining=$((deadline - SECONDS))
    [ "${remaining}" -gt 0 ] || return 1
    probe_seconds=$((remaining < 10 ? remaining : 10))
    main_pid=$(timeout --foreground --signal=TERM "${probe_seconds}s" \
        systemctl show "${service}" -p MainPID --value) || return 1
    remaining=$((deadline - SECONDS))
    [ "${remaining}" -gt 0 ] || return 1
    probe_seconds=$((remaining < 10 ? remaining : 10))
    control_group=$(timeout --foreground --signal=TERM "${probe_seconds}s" \
        systemctl show "${service}" -p ControlGroup --value) || return 1
    [[ "${main_pid}" =~ ^[1-9][0-9]*$ ]] || return 1
    cgroup_root="/sys/fs/cgroup${control_group}"
    [ -d "${cgroup_root}" ] || return 1
    shopt -s globstar nullglob
    for cgroup_file in "${cgroup_root}"/cgroup.procs "${cgroup_root}"/**/cgroup.procs; do
        [ -r "${cgroup_file}" ] || continue
        while IFS= read -r pid; do
            [ "${pid}" = "${main_pid}" ] || return 1
        done < "${cgroup_file}"
    done
}

wait_for_acknowledged_hold() {
    local started_at=${SECONDS} deadline remaining probe_seconds
    local hold_state service_state sleep_seconds
    deadline=$((started_at + wait_ceiling_s))
    while true; do
        remaining=$((deadline - SECONDS))
        if [ "${remaining}" -le 0 ]; then
            echo "[test-hold] no acknowledged idle reservation after ${wait_ceiling_s}s" >&2
            return 1
        fi
        probe_seconds=$((remaining < 10 ? remaining : 10))
        hold_state=$(hold_health_state "${probe_seconds}" 2>/dev/null || true)
        remaining=$((deadline - SECONDS))
        [ "${remaining}" -gt 0 ] || continue
        probe_seconds=$((remaining < 10 ? remaining : 10))
        service_state=$(timeout --foreground --signal=TERM "${probe_seconds}s" \
            systemctl is-active "${service}" 2>/dev/null || true)
        if [ "${hold_state}" = "ready" ] \
            && [ "${service_state//$'\n'/}" = "active" ] \
            && no_model_descendants "${deadline}"; then
            echo "[test-hold] runner acknowledged; no model work is active"
            return 0
        fi
        remaining=$((deadline - SECONDS))
        [ "${remaining}" -gt 0 ] || continue
        echo "[test-hold] waiting for runner acknowledgement ($((SECONDS - started_at))s elapsed)"
        sleep_seconds=$((remaining < wait_poll_s ? remaining : wait_poll_s))
        sleep "${sleep_seconds}"
    done
}

trap cleanup_remote EXIT
trap 'handle_remote_signal 130' HUP INT
trap 'handle_remote_signal 143' TERM
umask 077
printf '%s\n' "${owner_token}" > "${hold_path}"
wait_for_acknowledged_hold

sudo -u ubuntu -- bash -lc "${pytest_command}" &
test_pid=$!
test_status=0
if wait "${test_pid}"; then
    test_status=0
else
    test_status=$?
fi
test_pid=""
exit "${test_status}"
REMOTE_SCRIPT

    printf -v remote_command \
        "sudo -- flock --exclusive --nonblock --conflict-exit-code 75 %q bash -lc %q _ %q %q %q %q %q %q %q" \
        "${HOLD_PATH}" "${remote_script}" "${SERVICE}" "${PORT}" \
        "${HOLD_PATH}" "${WAIT_POLL_S}" "${WAIT_CEILING_S}" \
        "${HOLD_OWNER_TOKEN}" "${pytest_command}"
    printf '%s' "${remote_command}"
}

run_remote_hold_and_tests() {
    local remote_command remote_status=0
    remote_command=$(build_remote_test_command "$@")
    "${SSH[@]}" -o ConnectTimeout=20 librewxr "${remote_command}" &
    ACTIVE_SSH_PID=$!
    if wait "${ACTIVE_SSH_PID}"; then
        remote_status=0
    else
        remote_status=$?
    fi
    ACTIVE_SSH_PID=""
    REMOTE_STATUS="${remote_status}"
    if [ "${remote_status}" -eq 75 ]; then
        echo "[test-hold] another test runner already owns the marine hold" >&2
    fi
    return "${remote_status}"
}

verify_librewxr_fqdn
if [ "${release_only}" = "1" ]; then
    echo "[test-hold] releasing stale runner hold"
    release_hold_unconditionally
    exit $?
fi
trap cleanup EXIT
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

echo "[test-hold] requesting runner hold"
run_remote_hold_and_tests "$@"
