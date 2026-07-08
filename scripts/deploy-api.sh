#!/usr/bin/env bash
# deploy-api.sh — Deploy API changes to the weewx LXD container.
#
# Fired from any workstation (DILBERT, CATBERT, etc.) after pushing commits
# to GitHub. SSHes directly to weewx (not via ratbert lxc exec).
#
# Performs, in order:
#   1. git pull --ff-only as the ubuntu user (owns the repo)
#   2. restart the weewx-clearskies-api systemd service (as root)
#   3. wait for the API cache warmer to complete (~2 minutes)
#   4. verify the API responds on port 8765
#
# SSH config: uses the project-local config at .local/ssh/config so it works
# from any machine that has the replicated project files.
#
# Transport: direct SSH to weewx as `claude` user.
#   - git pull runs as the `ubuntu` user (owns the repos)
#   - service restarts use sudo (claude has NOPASSWD sudo)
#
# Verified weewx container facts (2026-07-08):
#   - Unit:     weewx-clearskies-api.service
#   - Repo:     /home/ubuntu/repos/weewx-clearskies-api
#   - Venv:     /home/ubuntu/repos/weewx-clearskies-api/.venv
#   - Config:   /etc/weewx-clearskies/api.conf
#   - Startup:  ~2 minutes (cache warmer runs before uvicorn binds to 8765)
#
# Usage:
#   ./scripts/deploy-api.sh               # full deploy (pull + restart + verify)
#   ./scripts/deploy-api.sh --skip-pull   # skip the git pull step
#   ./scripts/deploy-api.sh --no-restart  # pull only, no service restart
#
# Failures abort (set -euo pipefail). Each step prints a clear progress marker.

set -euo pipefail

REPO_PATH="/home/ubuntu/repos/weewx-clearskies-api"
SERVICE="weewx-clearskies-api"
API_PORT=8765
STARTUP_WAIT=130   # seconds — API cache warmer takes ~2 min

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSH_CONFIG="${PROJECT_ROOT}/.local/ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    echo "SSH config not found at ${SSH_CONFIG}" >&2
    echo "Ensure .local/ssh/config exists (replicated via Nextcloud)." >&2
    exit 1
fi

SSH_CMD="ssh -F ${SSH_CONFIG}"

skip_pull="0"
no_restart="0"
for arg in "$@"; do
    case "$arg" in
        --skip-pull) skip_pull="1" ;;
        --no-restart) no_restart="1" ;;
        *)
            echo "Unknown argument: '${arg}'" >&2
            echo "Usage: $0 [--skip-pull] [--no-restart]" >&2
            exit 1
            ;;
    esac
done

# Helper: run a command on weewx via sudo (for systemctl, etc.).
run_root() {
    $SSH_CMD weewx "sudo bash -lc '$1'"
}
# Helper: run a command on weewx as the ubuntu user (owns repos).
run_ubuntu() {
    $SSH_CMD weewx "sudo -u ubuntu bash -lc '$1'"
}

echo "=== Clear Skies API deploy → weewx ==="

# --- Step 1: git pull ---
if [ "$skip_pull" = "1" ]; then
    echo "--- [1/3] git pull: SKIPPED (--skip-pull) ---"
else
    echo "--- [1/3] git pull --ff-only ---"
    run_ubuntu "cd ${REPO_PATH} && git pull --ff-only"
    echo "[pull] ok"
fi

# --- Step 2: restart API service ---
if [ "$no_restart" = "1" ]; then
    echo "--- [2/3] service restart: SKIPPED (--no-restart) ---"
    echo "--- [3/3] verify: SKIPPED (no restart) ---"
    echo "=== Deploy complete (pull only, no restart) ==="
    exit 0
fi

echo "--- [2/3] restart ${SERVICE} ---"
run_root "systemctl restart ${SERVICE}"
echo "[svc] restart issued"

# The API cache warmer makes outbound provider API calls before uvicorn
# binds to port 8765. Wait for the service to become ready.
echo "[svc] waiting ${STARTUP_WAIT}s for cache warmer to complete..."
sleep "$STARTUP_WAIT"

# Confirm the service is active (not crashed during startup).
run_root "systemctl is-active --quiet ${SERVICE}"
echo "[svc] ${SERVICE} active"

# --- Step 3: verify API responds ---
echo "--- [3/3] verify API on port ${API_PORT} ---"
status_code=$($SSH_CMD weewx "curl -sk -o /dev/null -w '%{http_code}' https://localhost:${API_PORT}/health")
if [ "$status_code" = "200" ]; then
    echo "[verify] API health check: ${status_code} OK"
else
    echo "[verify] API health check returned ${status_code} (expected 200)" >&2
    echo "[verify] Check logs: ssh -F .local/ssh/config weewx 'journalctl -u ${SERVICE} --since \"3 min ago\" --no-pager'" >&2
    exit 1
fi

echo "=== API deploy complete ==="
echo "Verify through Caddy:  ssh -F .local/ssh/config weather-dev \"curl -s -o /dev/null -w '%{http_code}\\n' http://localhost/api/v1/current\""
