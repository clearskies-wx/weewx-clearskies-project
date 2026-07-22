#!/usr/bin/env bash
# deploy-compute.sh — Deploy the compute service to the librewxr LXD container.
#
# The compute service runs SwellTrack and SurfBeat on librewxr, offloading
# wave model computation from the weewx API host.
#
# Performs, in order:
#   1. Clone or pull the API repo on librewxr (as ubuntu user)
#   2. Install Python dependencies via uv
#   3. Install/update the systemd unit
#   4. Restart the service
#   5. Verify the health endpoint responds
#
# SSH config: uses the project-local config at .local/ssh/config.
# Transport: direct SSH to librewxr as `claude` user.
#
# Usage:
#   ./scripts/deploy-compute.sh               # full deploy
#   ./scripts/deploy-compute.sh --skip-pull    # skip the git pull step
#   ./scripts/deploy-compute.sh --no-restart   # pull + install only, no restart

set -euo pipefail

REPO_URL="https://github.com/clearskies-wx/weewx-clearskies-api.git"
REPO_PATH="/home/ubuntu/repos/weewx-clearskies-api"
SERVICE="weewx-clearskies-compute"
HEALTH_PORT=8770
STARTUP_WAIT=10   # compute service starts in <5 seconds (no cache warmer)

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

run_root() {
    $SSH_CMD librewxr "sudo bash -lc '$1'"
}
run_ubuntu() {
    $SSH_CMD librewxr "sudo -u ubuntu bash -lc '$1'"
}

echo "=== Clear Skies Compute Service deploy → librewxr ==="

# --- Step 1: Clone or pull the API repo ---
if [ "$skip_pull" = "1" ]; then
    echo "--- [1/4] git pull: SKIPPED (--skip-pull) ---"
else
    echo "--- [1/4] git clone/pull ---"
    # Check if repo exists
    if $SSH_CMD librewxr "test -d ${REPO_PATH}/.git" 2>/dev/null; then
        echo "[repo] pulling latest..."
        run_ubuntu "cd ${REPO_PATH} && git pull --ff-only"
    else
        echo "[repo] cloning..."
        run_ubuntu "mkdir -p /home/ubuntu/repos"
        run_ubuntu "cd /home/ubuntu/repos && git clone ${REPO_URL}"
    fi
    echo "[pull] ok"
fi

# --- Step 2: Install Python dependencies ---
echo "--- [2/4] install dependencies ---"
# Ensure uv is installed
if ! $SSH_CMD librewxr "which uv" >/dev/null 2>&1; then
    echo "[deps] installing uv..."
    run_root "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi
run_ubuntu "cd ${REPO_PATH} && uv sync --frozen 2>&1 | tail -3"
echo "[deps] ok"

# --- Step 3: Install/update systemd unit ---
echo "--- [3/4] systemd unit ---"
run_root "cat > /etc/systemd/system/${SERVICE}.service << 'UNIT'
[Unit]
Description=Clear Skies Compute Service (SwellTrack/SurfBeat)
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=${REPO_PATH}
EnvironmentFile=/etc/weewx-clearskies/secrets.env
ExecStart=${REPO_PATH}/.venv/bin/python -m weewx_clearskies_api.services.compute_service --port 8770
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT"
run_root "systemctl daemon-reload"
run_root "systemctl enable ${SERVICE}"
echo "[svc] unit installed"

# --- Step 4: Restart service ---
if [ "$no_restart" = "1" ]; then
    echo "--- [4/4] restart: SKIPPED (--no-restart) ---"
    echo "=== Deploy complete (no restart) ==="
    exit 0
fi

echo "--- [4/4] restart + verify ---"
run_root "systemctl restart ${SERVICE}"
echo "[svc] restart issued, waiting ${STARTUP_WAIT}s..."
sleep "$STARTUP_WAIT"

# Verify service is active
run_root "systemctl is-active --quiet ${SERVICE}"
echo "[svc] ${SERVICE} active"

# Verify health endpoint
status_code=$($SSH_CMD librewxr "curl -sk -o /dev/null -w '%{http_code}' https://localhost:${HEALTH_PORT}/health")
if [ "$status_code" = "200" ]; then
    echo "[verify] health check: ${status_code} OK"
else
    echo "[verify] health check returned ${status_code} (expected 200)" >&2
    echo "[verify] Check logs: ssh -F .local/ssh/config librewxr 'journalctl -u ${SERVICE} --since \"1 min ago\" --no-pager'" >&2
    exit 1
fi

echo "=== Compute service deploy complete ==="
