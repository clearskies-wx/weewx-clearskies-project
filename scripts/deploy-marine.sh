#!/usr/bin/env bash
# deploy-marine.sh — Deploy the unified marine companion service to librewxr.
#
# The marine service (weewx-clearskies-marine, ADR-099) is the standalone
# companion that owns ALL marine computation: wave physics (SWAN 3-level
# nested grid, SwellTrack, SurfBeat), tides (CO-OPS), buoy observations
# (NDBC), marine weather (NWS, WaveWatch III), ocean currents (OFS, ERDDAP),
# fishing conditions and beach safety. One service, one port (8780), one
# auth token. It replaces BOTH old librewxr services:
#
#   weewx-clearskies-swan.service     port 8767  (SWAN standalone)
#   weewx-clearskies-compute.service  port 8770  (SwellTrack/SurfBeat)
#
# Performs, in order:
#   1. Clone or pull weewx-clearskies-marine on librewxr (as ubuntu)
#   2. Create/refresh its OWN venv and install -e '.[nearshore]'
#   3. Verify the nearshore import surface (fail here, not at restart)
#   4. Provision /etc/weewx-clearskies/marine/ + MARINE_SERVICE_SECRET
#   5. Install/update the systemd unit
#   6. Restart and verify /health + /manifest
#
# SSH config: project-local at .local/ssh/config. Direct SSH to librewxr.
#
# Usage:
#   ./scripts/deploy-marine.sh                # full deploy
#   ./scripts/deploy-marine.sh --skip-pull    # skip the git pull step
#   ./scripts/deploy-marine.sh --no-restart   # install only, no restart
#   ./scripts/deploy-marine.sh --force-restart # restart even over an in-flight WW3 march/SWAN run
#   ./scripts/deploy-marine.sh --check-guard  # classify the service without mutation
#   ./scripts/deploy-marine.sh --show-secret  # print MARINE_SERVICE_SECRET and exit
#
# ---------------------------------------------------------------------------
# Host-specific notes — these are deployment facts, not preferences
# ---------------------------------------------------------------------------
#
# USER=ubuntu, NOT clearskies. The shipped unit in the repo
# (packaging/weewx-clearskies-marine.service) declares User=clearskies as its
# documented default. That user does not exist on librewxr, where both
# existing Clear Skies units run as `ubuntu` and every file under
# /etc/weewx-clearskies/ and /var/run/weewx-clearskies/ is ubuntu-owned.
# Creating a clearskies user would mean re-owning those trees, which
# CLAUDE.md "Filesystem permissions on containers" forbids and which would
# break the old services mid-transition. Match the host's existing user.
#
# ReadWritePaths must cover FOUR directories, not one. The shipped unit
# lists only /etc/weewx-clearskies/marine, which was correct for the Phase 4
# scaffold (TLS cert + marine.conf) but not after Phase 5 moved the SWAN code
# in. Under ProtectSystem=strict the service also needs:
#   /etc/weewx-clearskies          — swan_bathymetry_L*.json, swan_grid_sizing.json,
#                                    spot_profiles/, great_lakes/, operator_bathymetry/
#   /var/run/weewx-clearskies      — shared parent; the API's loop.sock lives here.
#                                    SWAN no longer writes under it (see next line) —
#                                    kept ONLY for the loop socket (SURF-REMEDIATION-
#                                    PLAN-2026-08-08 Phase R4).
#   /var/lib/weewx-clearskies/swan — SWAN work dirs, hotstart files, forecast_cache.json.
#                                    Real disk, not tmpfs. Moved off /var/run/weewx-
#                                    clearskies/swan (RAM-backed) in Phase R4: cgroup
#                                    memory accounting was charging the tmpfs pages to
#                                    the service (measured 5.1G memory peak vs a 6G cap).
# Without them every SWAN cycle fails on a read-only filesystem error.
#
# ITS OWN VENV, not the API repo's. deploy-compute.sh installs into the API
# repo's venv because both old services run from that interpreter. The marine
# service is self-contained by design (ADR-099) and gets its own, so that
# T8.4b archiving the old SWAN repo and any later removal of the API checkout
# on this host cannot strip its dependencies.
#
# `uv pip install`, never `uv sync`. Recorded in deploy-compute.sh and worth
# repeating: `uv sync --frozen` on 2026-07-25 pruned a host venv down to the
# lockfile's core set and left the service importless while systemd still
# reported `active`, because the running process held the old code in memory.
# There is no uv.lock in this repo; `uv pip install -e` resolves against
# pyproject.toml directly and prunes nothing.
#
# SWAN BINARY is a prerequisite, not a pip dependency. /usr/local/bin/swan
# must already exist on this host (it does — the old SWAN service uses it).
# Checked, not installed, by this script.

set -euo pipefail

REPO_URL="https://github.com/clearskies-wx/weewx-clearskies-marine.git"
REPO_PATH="/home/ubuntu/repos/weewx-clearskies-marine"
VENV="${REPO_PATH}/.venv"
CONF_DIR="/etc/weewx-clearskies/marine"
SECRETS="${CONF_DIR}/secrets.env"
SERVICE="weewx-clearskies-marine"
PORT=8780
HOST_IP="192.168.7.22"
SWAN_BINARY="/usr/local/bin/swan"
STARTUP_WAIT=15   # no cache warmer; TLS keygen on first start is the slow part

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSH_CONFIG="${PROJECT_ROOT}/.local/ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    echo "SSH config not found at ${SSH_CONFIG}" >&2
    exit 1
fi

SSH_CMD="ssh -F ${SSH_CONFIG}"

skip_pull="0"
no_restart="0"
show_secret="0"
force_restart="0"
check_guard="0"
for arg in "$@"; do
    case "$arg" in
        --skip-pull)     skip_pull="1" ;;
        --no-restart)    no_restart="1" ;;
        --force-restart) force_restart="1" ;;
        --check-guard)   check_guard="1" ;;
        --show-secret)   show_secret="1" ;;
        *)
            echo "Unknown argument: '${arg}'" >&2
            echo "Usage: $0 [--skip-pull] [--no-restart] [--force-restart] [--check-guard] [--show-secret]" >&2
            exit 1
            ;;
    esac
done

run_root() {
    $SSH_CMD librewxr "sudo bash -lc '$1'"
}
run_ubuntu() {
    $SSH_CMD librewxr "sudo -u ubuntu bash -lc '$1'"
}

# R0 deploy guard: no mutation may begin unless the service is proven idle.
# Health alone is insufficient because its in-process flags can be unavailable
# while WW3/SWAN descendants still occupy the service cgroup.
verify_librewxr_fqdn() {
    local configured_host

    if ! configured_host=$($SSH_CMD -G librewxr 2>/dev/null | awk '$1 == "hostname" { print $2; exit }'); then
        echo "[guard] FQDN check failed: could not read SSH configuration for librewxr" >&2
        return 1
    fi
    if [ "$configured_host" != "librewxr.shaneburkhardt.com" ]; then
        echo "[guard] FQDN check failed: librewxr resolves to '${configured_host:-missing}', expected librewxr.shaneburkhardt.com" >&2
        return 1
    fi
}

guard_classify() {
    local health_response health_body http_status health service descendants_raw classification

    if health_response=$($SSH_CMD -o ConnectTimeout=20 librewxr "curl -sk --max-time 10 --write-out \"\\n%{http_code}\" https://localhost:${PORT}/health" 2>/dev/null); then
        if [ -z "$health_response" ]; then
            health="malformed"
        else
            http_status="${health_response##*$'\n'}"
            if [[ "$http_status" =~ ^[0-9]{3}$ ]]; then
                health_body="${health_response%$'\n'*}"
                if [ "$http_status" != "200" ]; then
                    health="malformed"
                elif health=$(printf '%s' "$health_body" | $SSH_CMD -o ConnectTimeout=20 librewxr "python3 -c 'import json,sys; data=json.load(sys.stdin); in_flight=data[\"ww3Horizon\"][\"inFlight\"]; run_in_progress=data[\"run_in_progress\"]; assert type(in_flight) is bool and type(run_in_progress) is bool; print(\"busy\" if in_flight or run_in_progress else \"idle\")'" 2>/dev/null); then
                    case "$health" in
                        busy|idle) ;;
                        *) health="malformed" ;;
                    esac
                else
                    health="malformed"
                fi
            elif health=$(printf '%s' "$health_response" | $SSH_CMD -o ConnectTimeout=20 librewxr "python3 -c 'import json,sys; data=json.load(sys.stdin); in_flight=data[\"ww3Horizon\"][\"inFlight\"]; run_in_progress=data[\"run_in_progress\"]; assert type(in_flight) is bool and type(run_in_progress) is bool; print(\"busy\" if in_flight or run_in_progress else \"idle\")'" 2>/dev/null); then
                case "$health" in
                    busy|idle) ;;
                    *) health="malformed" ;;
                esac
            else
                health="malformed"
            fi
        fi
    else
        health="unreachable"
    fi

    if service=$($SSH_CMD -o ConnectTimeout=20 librewxr "systemctl is-active ${SERVICE}" 2>/dev/null); then
        :
    else
        :
    fi
    service="${service//$'\n'/}"
    case "$service" in
        active|activating|reloading|deactivating|maintenance|inactive|failed|unknown) ;;
        *) service="query-failure" ;;
    esac

    if descendants_raw=$(run_root "main_pid=\$(systemctl show ${SERVICE} -p MainPID --value) || exit 1; control_group=\$(systemctl show ${SERVICE} -p ControlGroup --value) || exit 1; [ -n \"\$main_pid\" ] || exit 1; child_found=0; if [ -n \"\$control_group\" ]; then cgroup_root=/sys/fs/cgroup\$control_group; [ -d \"\$cgroup_root\" ] || exit 1; shopt -s globstar nullglob; cgroup_files=(\"\$cgroup_root\"/cgroup.procs \"\$cgroup_root\"/**/cgroup.procs); [ \${#cgroup_files[@]} -gt 0 ] || exit 1; declare -A seen_pids; for cgroup_file in \"\${cgroup_files[@]}\"; do [ -r \"\$cgroup_file\" ] || exit 1; while IFS= read -r pid; do case \"\$pid\" in \"\"|*[!0-9]*) exit 1 ;; esac; [ \"\$pid\" = \"\$main_pid\" ] && continue; [ \"\${seen_pids[\$pid]+present}\" = present ] && continue; seen_pids[\$pid]=1; name=\$(ps -p \"\$pid\" -o comm=) || exit 1; [ -n \"\$name\" ] || exit 1; child_found=1; printf \"%s %s\\n\" \"\$pid\" \"\$name\"; done < \"\$cgroup_file\"; done; elif [ \"\$main_pid\" != 0 ]; then exit 1; fi; if [ \"\$main_pid\" = 0 ] && [ \"\$child_found\" = 0 ]; then printf \"__NO_MAIN__\\n\"; fi" 2>/dev/null); then
        if [ "$descendants_raw" = "__NO_MAIN__" ]; then
            case "$service" in
                inactive|failed) descendants="none" ;;
                *) descendants="query-failure" ;;
            esac
        elif [ -n "$descendants_raw" ]; then
            descendants="present"
        else
            descendants="none"
        fi
    else
        descendants="query-failure"
    fi

    if [ "$health" = "busy" ]; then
        classification="busy"
    elif [ "$health" = "idle" ] && [ "$service" = "active" ] && [ "$descendants" = "present" ]; then
        classification="busy"
    elif [ "$service" = "query-failure" ] || [ "$descendants" = "query-failure" ]; then
        classification="unknown-busy"
    elif [ "$health" = "idle" ] && [ "$service" = "active" ] && [ "$descendants" = "none" ]; then
        classification="idle"
    elif [ "$health" = "unreachable" ] \
        && { [ "$service" = "inactive" ] || [ "$service" = "failed" ]; } \
        && [ "$descendants" = "none" ]; then
        classification="idle"
    else
        classification="unknown-busy"
    fi

    echo "[guard] health=${health}; service=${service}; descendants=${descendants}; classification=${classification}"
    if [ "$classification" = "idle" ]; then
        return 0
    fi
    return 2
}

WAIT_POLL_S=60
WAIT_CEILING_S=23400

guard_before_mutation() {
    local status waited=0

    if [ "$force_restart" = "1" ]; then
        echo "[guard] --force-restart: bypassing deploy guard"
        return 0
    fi

    while true; do
        if guard_classify; then
            return 0
        else
            status=$?
        fi
        if [ "$status" -ne 2 ]; then
            return "$status"
        fi
        if [ "$waited" -ge "$WAIT_CEILING_S" ]; then
            echo "[guard] still busy or unknown after ${waited}s -- refusing the next mutation." >&2
            echo "[guard] re-run with --force-restart to bypass deliberately." >&2
            return 1
        fi
        if [ $((waited % 300)) -eq 0 ]; then
            echo "[guard] service is busy or unknown -- waiting (${waited}s elapsed, ceiling ${WAIT_CEILING_S}s)"
        fi
        sleep "$WAIT_POLL_S"
        waited=$((waited + WAIT_POLL_S))
    done
}

if ! verify_librewxr_fqdn; then
    exit 1
fi

if [ "$check_guard" = "1" ]; then
    guard_classify
    exit $?
fi

# --show-secret is a read-only query — handle it before anything else.
if [ "$show_secret" = "1" ]; then
    # No inner single quotes: run_root already wraps its argument in them.
    run_root "grep ^MARINE_SERVICE_SECRET= ${SECRETS} | cut -d= -f2-"
    exit 0
fi

echo "=== Clear Skies Marine Service deploy → librewxr:${PORT} ==="

# --- Step 0: prerequisites ---
echo "--- [0/6] prerequisites ---"
guard_before_mutation
if ! $SSH_CMD librewxr "test -x ${SWAN_BINARY}"; then
    echo "SWAN binary not found at ${SWAN_BINARY} on librewxr." >&2
    echo "The nearshore wave model cannot run without it. See the marine repo's" >&2
    echo "docs/INSTALL.md 'SWAN binary' section." >&2
    exit 1
fi
echo "[prereq] SWAN binary present at ${SWAN_BINARY}"
# The check must run as ubuntu, which is the user that will actually invoke
# uv below — `claude`'s PATH is not ubuntu's.
if ! $SSH_CMD librewxr "sudo -u ubuntu bash -lc 'command -v uv'" >/dev/null 2>&1; then
    echo "[prereq] installing uv..."
    run_root "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi
echo "[prereq] uv present"

# --- Step 1: clone or pull ---
if [ "$skip_pull" = "1" ]; then
    echo "--- [1/6] git pull: SKIPPED (--skip-pull) ---"
else
    echo "--- [1/6] git clone/pull ---"
    guard_before_mutation
    # The check MUST run as ubuntu: /home/ubuntu/repos is not readable by the
    # `claude` SSH user, so a bare `test -d` always fails and the script would
    # fall through to a clone that then aborts on "already exists".
    if $SSH_CMD librewxr "sudo -u ubuntu test -d ${REPO_PATH}/.git" 2>/dev/null; then
        echo "[repo] pulling latest..."
        run_ubuntu "cd ${REPO_PATH} && git pull --ff-only"
    else
        # weewx-clearskies-marine is a PRIVATE repo. `gh` is installed and
        # authenticated on librewxr as ubuntu (done 2026-07-23); it supplies
        # the credential an anonymous https clone would be refused.
        echo "[repo] cloning (private repo — via gh)..."
        run_ubuntu "mkdir -p /home/ubuntu/repos"
        run_ubuntu "cd /home/ubuntu/repos && gh repo clone clearskies-wx/weewx-clearskies-marine"
    fi
    run_ubuntu "cd ${REPO_PATH} && git log --oneline -1"
    echo "[pull] ok"
fi

# --- Step 2: venv + dependencies ---
echo "--- [2/6] venv + dependencies ---"
guard_before_mutation
if ! $SSH_CMD librewxr "sudo -u ubuntu test -x ${VENV}/bin/python" 2>/dev/null; then
    echo "[deps] creating venv..."
    run_ubuntu "cd ${REPO_PATH} && uv venv --python 3.12"
fi
run_ubuntu "cd ${REPO_PATH} && VIRTUAL_ENV=${VENV} uv pip install -e '.[nearshore]' 2>&1 | tail -5"
echo "[deps] ok (core + nearshore extra)"

# --- Step 3: verify the import surface ---
# Fail here with a readable error rather than at the next service restart,
# where it surfaces as a systemd unit that flaps on Restart=on-failure.
echo "--- [3/6] verify imports ---"
# Kept to ONE line deliberately. This string is interpolated through
# ssh -> sudo -u ubuntu bash -lc '...' -> python -c "..."; a multi-line body
# does not survive that quoting chain (it fails with "unexpected EOF while
# looking for matching quote", which reads like a Python error and is not).
run_ubuntu "${VENV}/bin/python -c \"import numpy, scipy, shapely, xarray, netCDF4, eccodes, prometheus_client, defusedxml, yaml, weewx_clearskies_marine.providers.nearshore.swan, weewx_clearskies_marine.services.swan_runner; from weewx_clearskies_marine.service import create_app; print(chr(105)+chr(109)+chr(112)+chr(111)+chr(114)+chr(116)+chr(115)+chr(32)+chr(111)+chr(107))\""
echo "[deps] import surface verified (core + nearshore + SWAN pipeline)"

# --- Step 4: config dir + secret ---
echo "--- [4/6] config dir + secret ---"
guard_before_mutation
run_root "install -d -o ubuntu -g ubuntu -m 0750 ${CONF_DIR}"
# Generate MARINE_SERVICE_SECRET once and never regenerate: rotating it here
# would silently break the API's Bearer auth on every redeploy. The API host
# holds the matching value in its own secrets.env (T8.2b).
# Branch on the client side. run_root wraps its argument in single quotes, so
# the remote command must contain none of its own — a multi-line if/else with
# quoted strings inside it dies with "syntax error: unexpected end of file".
if $SSH_CMD librewxr "sudo grep -q ^MARINE_SERVICE_SECRET= ${SECRETS}" 2>/dev/null; then
    echo "[secret] already present — left unchanged"
else
    run_root "umask 077; echo MARINE_SERVICE_SECRET=\$(openssl rand -hex 32) > ${SECRETS}; chown ubuntu:ubuntu ${SECRETS}; chmod 0600 ${SECRETS}"
    echo "[secret] generated"
fi
run_root "ls -l ${SECRETS}"

# --- Step 4b: WW3 binary pins (J24, operator order 2026-08-27) ---
# The WW3-leg runner refuses to run any ww3_* program whose sha256 does not
# match a configured pin (services/ww3_runner.py _verify_binaries, refuse
# slug ww3_binaries_invalid). Until 2026-08-27 those pins lived ONLY in a
# hand-placed `ww3` block inside marine.conf -- and every API config push
# rewrites marine.conf from a payload that has no `ww3` block, so the pins
# vanished on the first push and the 18Z leg refused. Operator order: "THIS
# ENTIRE SETUP HAS TO BE AUTOMATIC!" So this step hashes the installed
# programs on EVERY deploy and writes a host-local file the config push never
# touches; the marine config loader lays it over the pushed `ww3` block
# (config/__init__.py load_ww3_binaries, marine_config.py load_ww3_config).
# A missing program is a hard prerequisite failure, same standing as the SWAN
# binary check in step 0 -- the WW3 leg is part of the production chain.
echo "--- [4b] WW3 binary pins ---"
guard_before_mutation
WW3_BIN_DIR="/var/lib/weewx-clearskies/ww3/bin"
WW3_PROGRAMS="ww3_bound ww3_grid ww3_outp ww3_prep ww3_shel"
WW3_PINS_FILE="${CONF_DIR}/ww3-binaries.json"
for prog in ${WW3_PROGRAMS}; do
    # /var/lib/weewx-clearskies is not traversable by the claude SSH user;
    # the existence check has to run as root like the hashing below.
    if ! run_root "test -x ${WW3_BIN_DIR}/${prog}" >/dev/null 2>&1; then
        echo "WW3 program ${prog} not found at ${WW3_BIN_DIR} on librewxr." >&2
        echo "The WW3 deep-water leg cannot run without all five programs" >&2
        echo "(ww3_grid ww3_prep ww3_bound ww3_shel ww3_outp). See" >&2
        echo "docs/manuals/OPERATIONS-MANUAL.md 'WW3 deep-water leg' Build/install." >&2
        exit 1
    fi
done
# Staged through a local temp file and scp, like the unit below: run_root
# wraps its argument in single quotes, so JSON with quotes cannot be echoed
# through it. Hashes come back one per program; only the first field is kept.
PINS_TMP="$(mktemp)"
trap 'rm -f "${PINS_TMP}"' EXIT
{
    echo "{"
    echo "  \"generated_by\": \"scripts/deploy-marine.sh\","
    echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"binary_dir\": \"${WW3_BIN_DIR}\","
    echo "  \"binary_sha256\": {"
    sep=""
    for prog in ${WW3_PROGRAMS}; do
        line="$(run_root "sha256sum ${WW3_BIN_DIR}/${prog}")"
        hash="${line%% *}"
        if ! [[ "${hash}" =~ ^[0-9a-f]{64}$ ]]; then
            echo "sha256sum of ${prog} returned '${line}' -- not a sha256 hex digest." >&2
            exit 1
        fi
        echo "${sep}    \"${prog}\": \"${hash}\""
        sep=","
        echo "[pins] ${prog} ${hash}" >&2
    done
    echo "  }"
    echo "}"
} > "${PINS_TMP}"
scp -F "${SSH_CONFIG}" -q "${PINS_TMP}" "librewxr:/tmp/ww3-binaries.json"
run_root "install -o ubuntu -g ubuntu -m 0640 /tmp/ww3-binaries.json ${WW3_PINS_FILE} && rm -f /tmp/ww3-binaries.json"
run_root "ls -l ${WW3_PINS_FILE}"
echo "[pins] ${WW3_PINS_FILE} written (5 programs)"

# --- Step 5: systemd unit ---
echo "--- [5/6] systemd unit ---"
guard_before_mutation
# Staged through a local file and scp, NOT a remote heredoc. run_root wraps
# its argument in single quotes, so `cat > file << 'UNIT'` closes that wrapper
# on its own quotes and the rest of the unit is executed as shell commands.
# deploy-compute.sh carries the same latent bug in its unit-install step.
UNIT_TMP="$(mktemp)"
trap 'rm -f "${UNIT_TMP}" "${PINS_TMP}"' EXIT
cat > "${UNIT_TMP}" << UNIT
[Unit]
Description=Clear Skies Marine Companion Service (SWAN/SwellTrack/SurfBeat, tides, buoy, marine weather)
Documentation=https://github.com/clearskies-wx/weewx-clearskies-marine
After=network.target

[Service]
Type=simple
# librewxr runs every Clear Skies service as ubuntu and owns
# /etc/weewx-clearskies and /var/run/weewx-clearskies as ubuntu. The repo's
# shipped unit documents User=clearskies as the default; this host matches
# its own existing user instead. See scripts/deploy-marine.sh header.
User=ubuntu
Group=ubuntu
WorkingDirectory=${CONF_DIR}
# systemd does NOT support shell-style \${VAR:-default} in ExecStart — it
# substitutes only bare \${VAR} and passes anything else through literally, so
# the service dies with getaddrinfo("\${CLEARSKIES_MARINE_BIND_HOST:-0.0.0.0}").
# Declare the default with Environment= FIRST, then let the optional
# network.env override it: systemd applies these in file order, so a value in
# network.env wins over the Environment= line above it.
Environment=CLEARSKIES_MARINE_BIND_HOST=0.0.0.0
EnvironmentFile=${SECRETS}
EnvironmentFile=-${CONF_DIR}/network.env
ExecStart=${VENV}/bin/weewx-clearskies-marine --host \${CLEARSKIES_MARINE_BIND_HOST} --port ${PORT} --cert-dir ${CONF_DIR} --hostname ${HOST_IP}
Restart=on-failure
RestartSec=5

NoNewPrivileges=true
ProtectSystem=strict
PrivateTmp=true
# FOUR paths, not one. TLS cert + marine.conf live in ${CONF_DIR}; the SWAN
# pipeline moved in at Phase 5 also writes bathymetry caches, grid sizing and
# spot profiles under /etc/weewx-clearskies. /var/run/weewx-clearskies is kept
# ONLY for the API's loop.sock -- SWAN no longer writes there (Phase R4). SWAN
# work dirs, hotstart files and forecast cache now live on real disk under
# /var/lib/weewx-clearskies/swan (SURF-REMEDIATION-PLAN-2026-08-08 Phase R4:
# /var/run was tmpfs, and cgroup memory accounting charged those pages to the
# service). Under ProtectSystem=strict, omitting any of these makes every SWAN
# cycle fail on a read-only filesystem.
ReadWritePaths=${CONF_DIR}
ReadWritePaths=/etc/weewx-clearskies
ReadWritePaths=/var/run/weewx-clearskies
ReadWritePaths=/var/lib/weewx-clearskies/swan
# /var/run (= /run) is tmpfs: after a host reboot /run/weewx-clearskies does
# not exist, and a ReadWritePaths entry naming a missing path fails mount-
# namespace setup (status=226/NAMESPACE) -> immediate crash loop. This was
# the 2026-08-10 startup crash-loop root cause (marine fixit Item 0); the
# operator repaired it live and the 2026-08-11 B2 unit reinstall regressed
# it because the fix was only on the host, not here. RuntimeDirectory makes
# systemd CREATE the directory (unit User= ownership, no chown) before
# namespacing; Preserve=yes stops deletion on service stop (on a host where
# the API's loop.sock lives here, deleting on marine stop would yank the
# socket dir out from under the API).
RuntimeDirectory=weewx-clearskies
RuntimeDirectoryPreserve=yes
# The B1 DEBUG trace (services/trace.py) writes
# /var/log/weewx-clearskies/marine-trace-{YYYYMMDD}.jsonl when
# CLEARSKIES_MARINE_DEBUG_TRACE is set. /var is read-only under
# ProtectSystem=strict and the directory did not exist, so the trace silently
# degraded to its own cannot-open path. LogsDirectory rather than a fourth
# ReadWritePaths line: systemd creates the directory owned by User= above, so
# no chown is needed here (CLAUDE.md bans chown/chmod on these hosts).
LogsDirectory=weewx-clearskies

[Install]
WantedBy=multi-user.target
UNIT
scp -F "${SSH_CONFIG}" -q "${UNIT_TMP}" "librewxr:/tmp/${SERVICE}.service"
run_root "install -o root -g root -m 0644 /tmp/${SERVICE}.service /etc/systemd/system/${SERVICE}.service && rm -f /tmp/${SERVICE}.service"
run_root "systemctl daemon-reload"
run_root "systemctl enable ${SERVICE}"
echo "[svc] unit installed and enabled"

# --- Bootstrap: /var/lib/weewx-clearskies/swan (Phase R4) ---
# /var/lib/weewx-clearskies exists root-owned on librewxr already (14 GB of
# unrelated root content) -- this creates ONLY the swan/ subdirectory, owned
# by ubuntu, without touching or re-owning anything else under the parent
# (lead ruling, SURF-REMEDIATION-PLAN-2026-08-08 Phase R4.1(e); CLAUDE.md
# bans chown on existing content). Idempotent: install -d no-ops if the
# directory already exists with the right owner/mode.
echo "--- bootstrap: /var/lib/weewx-clearskies/swan ---"
guard_before_mutation
run_root "install -d -o ubuntu -g ubuntu -m 0750 /var/lib/weewx-clearskies/swan"
echo "[bootstrap] /var/lib/weewx-clearskies/swan ready"

# --- Migrate: SWAN working-tree state, /var/run -> /var/lib (Phase R4) ---
# Runs once, idempotent: only copies when the OLD (tmpfs) forecast cache
# exists AND the NEW root does not have it yet. Copy, not move -- the old
# tree is left in place; the lead deletes it manually after the first
# verified post-move cycle (not scripted here, per Phase R4.3 design). This
# avoids the D-1a forecast-gap lesson: moving the cache aside cost a
# forecast gap; copying does not.
echo "--- migrate: SWAN state /var/run -> /var/lib (Phase R4, one-time) ---"
guard_before_mutation
OLD_SWAN_ROOT=/var/run/weewx-clearskies/swan
NEW_SWAN_ROOT=/var/lib/weewx-clearskies/swan
if $SSH_CMD librewxr "sudo -u ubuntu test -f ${OLD_SWAN_ROOT}/forecast_cache.json" 2>/dev/null \
   && ! $SSH_CMD librewxr "sudo -u ubuntu test -f ${NEW_SWAN_ROOT}/forecast_cache.json" 2>/dev/null; then
    echo "[migrate] old SWAN state found, new root empty -- copying (preserving mtimes)"
    run_ubuntu "cp -a ${OLD_SWAN_ROOT}/forecast_cache.json ${NEW_SWAN_ROOT}/ 2>/dev/null || true"
    run_ubuntu "cp -a ${OLD_SWAN_ROOT}/wind_timeline.json ${NEW_SWAN_ROOT}/ 2>/dev/null || true"
    run_ubuntu "cp -a ${OLD_SWAN_ROOT}/incoming.json ${NEW_SWAN_ROOT}/ 2>/dev/null || true"
    run_ubuntu "cp -a ${OLD_SWAN_ROOT}/profile_store ${NEW_SWAN_ROOT}/ 2>/dev/null || true"
    run_ubuntu "cp -a ${OLD_SWAN_ROOT}/level*_hotstart_*.dat ${NEW_SWAN_ROOT}/ 2>/dev/null || true"
    echo "[migrate] copy complete -- old tree left in place at ${OLD_SWAN_ROOT}; delete manually after first verified post-move cycle"
else
    echo "[migrate] nothing to do (old state absent, or new root already populated)"
fi

# --- Step 6: restart + verify ---
if [ "$no_restart" = "1" ]; then
    echo "--- [6/6] restart: SKIPPED (--no-restart) ---"
    # D4 (T0.2): a --no-restart deploy leaves the OLD process running the OLD
    # code. Make that impossible to mistake for a live deploy by printing the
    # unchanged process start-time with a STALE banner. The three manual
    # `git pull`s on 2026-07-29 that voided a whole session's evidence looked
    # exactly like a successful deploy in the logs; this line is why they can't
    # anymore.
    STALE_START=$(run_root "systemctl show ${SERVICE} -p ExecMainStartTimestamp --value")
    echo "[verify] STALE PROCESS — service not restarted; running process predates this deploy (ExecMainStartTimestamp ${STALE_START})"
    echo "=== Deploy complete (no restart) ==="
    exit 0
fi

echo "--- [6/6] restart + verify ---"
guard_before_mutation
run_root "systemctl restart ${SERVICE}"
echo "[svc] restart issued, waiting ${STARTUP_WAIT}s..."
sleep "$STARTUP_WAIT"

if ! run_root "systemctl is-active --quiet ${SERVICE}"; then
    echo "[svc] ${SERVICE} is NOT active" >&2
    $SSH_CMD librewxr "sudo journalctl -u ${SERVICE} --since '2 min ago' --no-pager | tail -40" >&2
    exit 1
fi
echo "[svc] ${SERVICE} active"

# D4 (T0.2): make "what commit is actually running, since when" impossible to
# miss. The D4 failure mode was not a missing restart — it was code pulled to
# disk while the running process kept executing the pre-fix commit. Printing
# the deployed commit alongside the process start-time lets any later
# acceptance block cite both, and lets a stale process be spotted at a glance.
DEPLOYED_COMMIT=$(run_ubuntu "cd ${REPO_PATH} && git rev-parse --short HEAD")
PROC_START=$(run_root "systemctl show ${SERVICE} -p ExecMainStartTimestamp --value")
echo "[verify] running commit ${DEPLOYED_COMMIT}; process started ${PROC_START}"

# /health and /manifest are the two unauthenticated endpoints (ARCHITECTURE.md
# port registry, port 8780). Everything else requires the Bearer token.
for ep in health manifest; do
    code=$($SSH_CMD librewxr "curl -sk -o /dev/null -w '%{http_code}' https://localhost:${PORT}/${ep}")
    if [ "$code" = "200" ]; then
        echo "[verify] GET /${ep}: ${code} OK"
    else
        echo "[verify] GET /${ep} returned ${code} (expected 200)" >&2
        echo "[verify] logs: ssh -F .local/ssh/config librewxr 'sudo journalctl -u ${SERVICE} --since \"2 min ago\" --no-pager'" >&2
        exit 1
    fi
done

# Auth must actually be enforced — a service that 200s an unauthenticated
# marine request has its auth wired wrong, and that is worth catching at
# deploy time rather than in an audit.
code=$($SSH_CMD librewxr "curl -sk -o /dev/null -w '%{http_code}' https://localhost:${PORT}/discovery/swan-check")
if [ "$code" = "401" ]; then
    echo "[verify] unauthenticated /discovery/swan-check: 401 — auth enforced"
else
    echo "[verify] unauthenticated /discovery/swan-check returned ${code} (expected 401)" >&2
    exit 1
fi

echo "=== Marine service deploy complete → https://${HOST_IP}:${PORT} ==="
