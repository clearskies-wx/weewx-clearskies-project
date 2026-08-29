#!/usr/bin/env bash
# Guard tests for the R0 deploy-marine safety controller.  They execute a
# disposable copy of the deploy script with PATH pointing at fake ssh/sleep;
# no command can reach librewxr or mutate production.
set -euo pipefail

readonly TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SOURCE_SCRIPT="${TEST_ROOT}/scripts/deploy-marine.sh"
readonly SCRATCH_ROOT="${TEST_ROOT}/scratch/r0-guard-tests"
readonly CASE_ROOT="${SCRATCH_ROOT}/case"
readonly COPY_SCRIPT="${CASE_ROOT}/scripts/deploy-marine.sh"
readonly FAKE_BIN="${CASE_ROOT}/bin"
readonly TRANSCRIPT="${CASE_ROOT}/transcript.txt"

cleanup() {
    rm -rf -- "${SCRATCH_ROOT}"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

require_contains() {
    local needle="$1"
    local file="$2"
    grep -Fq -- "$needle" "$file" || fail "missing ${needle@Q} in ${file}"
}

setup_case_root() {
    mkdir -p "${CASE_ROOT}/scripts" "${CASE_ROOT}/.local/ssh" "${CASE_ROOT}/tmp" "${FAKE_BIN}"
    cp -- "${SOURCE_SCRIPT}" "${COPY_SCRIPT}"
    # Copy an executable shell first; redirection below preserves its mode without chmod.
    cp -- /bin/bash "${FAKE_BIN}/ssh"
    cp -- /bin/bash "${FAKE_BIN}/sleep"
    cp -- /bin/bash "${FAKE_BIN}/scp"
    : > "${CASE_ROOT}/.local/ssh/config"
    export FAKE_SSH_LOG="${CASE_ROOT}/ssh.log"
    export FAKE_MUTATION_LOG="${CASE_ROOT}/mutation.log"
    export FAKE_SLEEP_LOG="${CASE_ROOT}/sleep.log"
    export FAKE_SCP_LOG="${CASE_ROOT}/scp.log"
    cat > "${FAKE_BIN}/ssh" <<'FAKE_SSH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${FAKE_SSH_LOG}"

for arg in "$@"; do
    if [ "$arg" = "-G" ]; then
        printf 'hostname librewxr.shaneburkhardt.com\n'
        exit 0
    fi
done

command="${!#}"
case "$command" in
    *curl*'-w '*'/health'*)
        printf '200\n'
        ;;
    *curl*'-w '*'/manifest'*)
        printf '200\n'
        ;;
    *curl*'-w '*'/discovery/swan-check'*)
        printf '401\n'
        ;;
    *curl*health*)
        case "${FAKE_HEALTH}" in
            busy)        printf '%s\n' '{"ww3Horizon":{"inFlight":true},"run_in_progress":false}' ;;
            idle)        printf '%s\n' '{"ww3Horizon":{"inFlight":false},"run_in_progress":false}' ;;
            malformed)   printf '%s\n' '{not-json' ;;
            unreachable) exit 255 ;;
        esac
        ;;
    *'sha256sum '*)
        printf '%064d  %s\n' 0 /fake/program
        ;;
    *'git rev-parse --short HEAD'*)
        printf '0123abcd\n'
        ;;
    *'ExecMainStartTimestamp'*)
        printf 'Thu 2026-08-29 12:00:00 UTC\n'
        ;;
    *'systemctl is-active'*)
        if [ "${FAKE_SERVICE}" = "query-failure" ]; then
            exit 1
        fi
        printf '%s\n' "${FAKE_SERVICE}"
        if [ "${FAKE_SERVICE}" = "inactive" ] || [ "${FAKE_SERVICE}" = "failed" ]; then
            exit 3
        fi
        ;;
    *'MainPID'*|*'ControlGroup'*|*'cgroup.procs'*|*'/proc/'*)
        if [ "${FAKE_DESCENDANTS}" = "query-failure" ]; then
            exit 1
        fi
        case "${FAKE_DESCENDANTS}" in
            none)    : ;;
            present) printf '4711 %s\n' "${FAKE_CHILD}" ;;
        esac
        ;;
    *'systemctl restart'*|*'systemctl daemon-reload'*|*'systemctl enable'*|*'git pull'*|*'gh repo clone'*|*'uv '*|*'install '*|*'cp -a '*|*'scp '*)
        printf '%s\n' "MUTATION: ${command}" >> "${FAKE_MUTATION_LOG}"
        ;;
esac
FAKE_SSH
    cat > "${FAKE_BIN}/sleep" <<'FAKE_SLEEP'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_SLEEP_LOG}"
FAKE_SLEEP
    cat > "${FAKE_BIN}/scp" <<'FAKE_SCP'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${FAKE_SCP_LOG}"
FAKE_SCP
}

expected_exit() {
    local health="$1"
    local service="$2"
    local descendants="$3"

    if [ "$health" = "busy" ]; then
        printf '2\n'
    elif [ "$service" = "query-failure" ] || [ "$descendants" = "query-failure" ]; then
        printf '2\n'
    elif [ "$health" = "idle" ] && [ "$service" = "active" ] && [ "$descendants" = "none" ]; then
        printf '0\n'
    elif [ "$health" = "unreachable" ] \
        && { [ "$service" = "inactive" ] || [ "$service" = "failed" ]; } \
        && [ "$descendants" = "none" ]; then
        printf '0\n'
    else
        printf '2\n'
    fi
}

run_check_case() {
    local health="$1"
    local service="$2"
    local descendants="$3"
    local expected
    local actual
    local child="${4:-ww3_shel}"
    expected="$(expected_exit "$health" "$service" "$descendants")"

    : > "${FAKE_SSH_LOG}"
    : > "${FAKE_MUTATION_LOG}"
    : > "${FAKE_SLEEP_LOG}"
    : > "${FAKE_SCP_LOG}"
    set +e
    PATH="${FAKE_BIN}:${PATH}" \
        FAKE_HEALTH="$health" \
        FAKE_SERVICE="$service" \
        FAKE_DESCENDANTS="$descendants" \
        FAKE_CHILD="$child" \
        FAKE_SSH_LOG="${FAKE_SSH_LOG}" \
        FAKE_MUTATION_LOG="${FAKE_MUTATION_LOG}" \
        FAKE_SLEEP_LOG="${FAKE_SLEEP_LOG}" \
        FAKE_SCP_LOG="${FAKE_SCP_LOG}" \
        TMPDIR="${CASE_ROOT}/tmp" \
        bash "${COPY_SCRIPT}" --check-guard >"${TRANSCRIPT}" 2>&1
    actual=$?
    set -e

    if [ "$actual" -ne "$expected" ]; then
        printf 'FAIL: check-only health=%s service=%s descendants=%s: expected exit %s, got %s\n' \
            "$health" "$service" "$descendants" "$expected" "$actual" >&2
        printf '%s\n' '--- raw deploy transcript ---' >&2
        cat "${TRANSCRIPT}" >&2
        printf '%s\n' '--- end raw deploy transcript ---' >&2
        exit 1
    fi
    [ ! -s "${FAKE_MUTATION_LOG}" ] || fail "check-only mutated for health=${health} service=${service} descendants=${descendants}"
    [ ! -s "${FAKE_SLEEP_LOG}" ] || fail "check-only waited for health=${health} service=${service} descendants=${descendants}"
    [ ! -s "${FAKE_SCP_LOG}" ] || fail "check-only copied files for health=${health} service=${service} descendants=${descendants}"
    require_contains 'health' "${TRANSCRIPT}"
    require_contains 'service' "${TRANSCRIPT}"
    require_contains 'descendant' "${TRANSCRIPT}"
}

test_named_child_cases() {
    local child
    for child in ww3_shel swan ancillary-child; do
        run_check_case idle active present "$child"
    done
    printf 'ok: named WW3, SWAN, and ancillary cgroup child cases\n'
}

test_cartesian_check_only_matrix() {
    local health
    local service
    local descendants
    local cases=0
    for health in busy idle unreachable malformed; do
        for service in active activating reloading deactivating maintenance inactive failed unknown query-failure; do
            for descendants in none present query-failure; do
                run_check_case "$health" "$service" "$descendants"
                cases=$((cases + 1))
            done
        done
    done
    [ "$cases" -eq 108 ] || fail "matrix case count was ${cases}, expected 108"
    printf 'ok: 108 check-only classification cases\n'
}

test_force_override() {
    : > "${FAKE_MUTATION_LOG}"
    : > "${FAKE_SLEEP_LOG}"
    : > "${FAKE_SCP_LOG}"
    set +e
    PATH="${FAKE_BIN}:${PATH}" FAKE_HEALTH=busy FAKE_SERVICE=active FAKE_DESCENDANTS=present \
        FAKE_SSH_LOG="${FAKE_SSH_LOG}" FAKE_MUTATION_LOG="${FAKE_MUTATION_LOG}" FAKE_SLEEP_LOG="${FAKE_SLEEP_LOG}" FAKE_SCP_LOG="${FAKE_SCP_LOG}" TMPDIR="${CASE_ROOT}/tmp" \
        bash "${COPY_SCRIPT}" --skip-pull --force-restart >"${TRANSCRIPT}" 2>&1
    local actual=$?
    set -e
    [ "$actual" -eq 0 ] || fail "force override expected exit 0, got ${actual}: $(<"${TRANSCRIPT}")"
    require_contains 'systemctl restart' "${FAKE_MUTATION_LOG}"
    [ ! -s "${FAKE_SLEEP_LOG}" ] || fail 'force override waited instead of bypassing the guard'
}

test_wait_timeout() {
    : > "${FAKE_MUTATION_LOG}"
    : > "${FAKE_SLEEP_LOG}"
    sed -i 's/^WAIT_CEILING_S=23400$/WAIT_CEILING_S=120/' "${COPY_SCRIPT}"
    require_contains 'WAIT_CEILING_S=120' "${COPY_SCRIPT}"
    set +e
    PATH="${FAKE_BIN}:${PATH}" FAKE_HEALTH=busy FAKE_SERVICE=active FAKE_DESCENDANTS=none \
        FAKE_SSH_LOG="${FAKE_SSH_LOG}" FAKE_MUTATION_LOG="${FAKE_MUTATION_LOG}" FAKE_SLEEP_LOG="${FAKE_SLEEP_LOG}" FAKE_SCP_LOG="${FAKE_SCP_LOG}" TMPDIR="${CASE_ROOT}/tmp" \
        bash "${COPY_SCRIPT}" --skip-pull >"${TRANSCRIPT}" 2>&1
    local actual=$?
    set -e
    [ "$actual" -ne 0 ] || fail 'busy wait timeout unexpectedly succeeded'
    [ ! -s "${FAKE_MUTATION_LOG}" ] || fail 'busy wait timeout mutated a guarded phase'
    [ -s "${FAKE_SLEEP_LOG}" ] || fail 'busy wait timeout did not wait at the configured cadence'
}

is_guard_invocation() {
    local line="$1"
    [[ "$line" =~ (^|[^[:alnum:]_])[[:alnum:]_]*guard[[:alnum:]_]* ]] || return 1
    [[ ! "$line" =~ ^[[:space:]]*(function[[:space:]]+)?[[:alnum:]_]+[[:space:]]*\(\)[[:space:]]*\{ ]] || return 1
    [[ ! "$line" =~ ^[[:space:]]*(echo|printf)[[:space:]] ]] || return 1
}

first_mutation_after() {
    local phase_pattern="$1"
    local mutation_pattern="$2"
    awk -v phase="$phase_pattern" -v mutation="$mutation_pattern" '
        !started && $0 ~ phase { started=1; next }
        started && $0 !~ /^[[:space:]]*#/ && $0 ~ mutation { print NR; exit }
    ' "${COPY_SCRIPT}"
}

assert_phase_guarded() {
    local phase_name="$1"
    local phase_pattern="$2"
    local mutation_pattern="$3"
    local mutation_line
    local guard_line
    mutation_line="$(first_mutation_after "$phase_pattern" "$mutation_pattern")"
    [ -n "$mutation_line" ] || fail "${phase_name}: mutation pattern absent after phase start"
    guard_line="$(awk -v phase="$phase_pattern" -v mutation_line="$mutation_line" '
        !started && $0 ~ phase { started=1; next }
        started && NR < mutation_line && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*(function[[:space:]]+)?[[:alnum:]_]+[[:space:]]*\(\)[[:space:]]*\{/ && $0 !~ /^[[:space:]]*(echo|printf)[[:space:]]/ && /(^|[^[:alnum:]_])[[:alnum:]_]*guard[[:alnum:]_]*/ { print NR; exit }
    ' "${COPY_SCRIPT}")"
    [ -n "$guard_line" ] || fail "${phase_name}: no guard invocation after phase start and before mutation at line ${mutation_line}"
}

test_static_guard_ordering() {
    require_contains --check-guard "${COPY_SCRIPT}"
    require_contains 'WAIT_CEILING_S=23400' "${SOURCE_SCRIPT}"
    assert_phase_guarded prerequisites 'Step 0: prerequisites' 'curl .*uv/install'
    assert_phase_guarded source 'Step 1: clone or pull' 'git pull|gh repo clone'
    assert_phase_guarded environment 'Step 2: venv' 'uv venv|uv pip install'
    assert_phase_guarded secret 'Step 4: config dir' 'install -d.*CONF_DIR'
    assert_phase_guarded pins 'Step 4b: WW3 binary pins' 'PINS_TMP='
    assert_phase_guarded unit 'Step 5: systemd unit' 'UNIT_TMP='
    assert_phase_guarded bootstrap 'Bootstrap:' 'install -d.*var/lib/weewx-clearskies/swan'
    assert_phase_guarded migration 'Migrate:' 'cp -a.*OLD_SWAN_ROOT'
    assert_phase_guarded restart 'Step 6: restart' 'systemctl restart'
    local restart_line
    local preceding_line
    restart_line="$(grep -n 'systemctl restart' "${COPY_SCRIPT}" | tail -1 | cut -d: -f1)"
    preceding_line="$(awk -v restart_line="$restart_line" 'NR < restart_line && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ { line=$0 } END { print line }' "${COPY_SCRIPT}")"
    is_guard_invocation "$preceding_line" || fail 'restart is not immediately preceded by a guard invocation'
}

setup_case_root
bash -n "${COPY_SCRIPT}"
test_cartesian_check_only_matrix
test_named_child_cases
test_wait_timeout
test_force_override
test_static_guard_ordering
printf 'ok: deploy-marine R0 guard tests complete\n'
