#!/usr/bin/env bash
# deploy-librewxr.sh — Deploy the LibreWXR radar fork to the librewxr LXD container.
#
# The radar service (our fork of JoshuaKimsey/LibreWXR, github.com/inguy24/LibreWXR)
# runs as a Docker container on the librewxr LXC. There is NO git checkout on the
# container: /opt/librewxr/src is a source snapshot, and the compose file runs the
# locally-built image `librewxr-bbox:latest`. This script mirrors the manual
# procedure from the 2026-08-05 satellite CPU-burn round.
#
# Performs, in order:
#   1. Pre-flight: local repo clean, record the deployed commit
#   2. git-archive the branch -> extract to /opt/librewxr/src.new on the LXC
#   3. Swap trees (previous tree kept at /opt/librewxr/src.old for rollback)
#   4. docker build -t librewxr-bbox:latest
#   5. docker compose up -d + poll /health until 200
#
# NOTE: recreating the container empties the in-memory tile cache; the first
# satellite warm after a deploy is a full rebuild (~25 min at ~1 core). Tiles
# still serve on-demand during the rebuild — this is a background cost, not an
# outage.
#
# Rollback: swap src.old back and rebuild —
#   ssh -F .local/ssh/config librewxr "sudo mv /opt/librewxr/src /opt/librewxr/src.bad \
#     && sudo mv /opt/librewxr/src.old /opt/librewxr/src \
#     && sudo docker build -t librewxr-bbox:latest /opt/librewxr/src \
#     && cd /opt/librewxr && sudo docker compose up -d"
#
# Usage:
#   ./scripts/deploy-librewxr.sh              # deploy local deploy/shaneburkhardt
#   ./scripts/deploy-librewxr.sh <ref>        # deploy a specific local ref

set -euo pipefail

BRANCH="${1:-deploy/shaneburkhardt}"
HEALTH_PORT=8080
HEALTH_TRIES=12   # x 15s = up to 3 min; app loads disk frame caches at startup
CONTAINER="librewxr-librewxr-1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO="${PROJECT_ROOT}/repos/librewxr"
SSH_CONFIG="${PROJECT_ROOT}/.local/ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    echo "SSH config not found at ${SSH_CONFIG}" >&2
    exit 1
fi
SSH_CMD="ssh -F ${SSH_CONFIG}"

echo "=== LibreWXR radar deploy → librewxr ==="

# --- Step 1: pre-flight ---
echo "--- [1/5] pre-flight ---"
if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
    echo "[preflight] working tree not clean — commit or stash first" >&2
    exit 1
fi
COMMIT=$(git -C "$REPO" rev-parse --short "$BRANCH")
if ! git -C "$REPO" merge-base --is-ancestor "$BRANCH" "origin/${BRANCH}" 2>/dev/null \
   && ! git -C "$REPO" merge-base --is-ancestor "origin/${BRANCH}" "$BRANCH" 2>/dev/null; then
    echo "[preflight] WARNING: ${BRANCH} and origin/${BRANCH} have diverged" >&2
fi
if [ "$(git -C "$REPO" rev-parse "$BRANCH")" != "$(git -C "$REPO" rev-parse "origin/${BRANCH}" 2>/dev/null)" ]; then
    echo "[preflight] WARNING: deploying ${COMMIT}, which differs from origin/${BRANCH} — push first if this is unintended"
fi
echo "[preflight] deploying ${BRANCH} @ ${COMMIT}"

# --- Step 2: stage source tree ---
echo "--- [2/5] stage source → src.new ---"
git -C "$REPO" archive --format=tar "$BRANCH" | $SSH_CMD librewxr \
    "sudo rm -rf /opt/librewxr/src.new && sudo mkdir -p /opt/librewxr/src.new && sudo tar -xf - -C /opt/librewxr/src.new"
$SSH_CMD librewxr "echo '${COMMIT}' | sudo tee /opt/librewxr/src.new/DEPLOYED_COMMIT >/dev/null && sudo test -f /opt/librewxr/src.new/Dockerfile"
echo "[stage] ok (DEPLOYED_COMMIT=${COMMIT})"

# --- Step 3: swap trees ---
echo "--- [3/5] swap (previous tree → src.old) ---"
$SSH_CMD librewxr "sudo rm -rf /opt/librewxr/src.old && sudo mv /opt/librewxr/src /opt/librewxr/src.old && sudo mv /opt/librewxr/src.new /opt/librewxr/src"
echo "[swap] ok"

# --- Step 4: build image ---
echo "--- [4/5] docker build ---"
$SSH_CMD librewxr "sudo docker build -t librewxr-bbox:latest /opt/librewxr/src 2>&1 | tail -3"
echo "[build] ok"

# --- Step 5: up + health ---
echo "--- [5/5] compose up + health ---"
$SSH_CMD librewxr "cd /opt/librewxr && sudo docker compose up -d 2>&1 | tail -2"
for i in $(seq 1 "$HEALTH_TRIES"); do
    sleep 15
    status_code=$($SSH_CMD librewxr "curl -s -o /dev/null -w '%{http_code}' http://localhost:${HEALTH_PORT}/health" || true)
    if [ "$status_code" = "200" ]; then
        echo "[verify] health check: 200 OK (attempt ${i})"
        $SSH_CMD librewxr "sudo docker ps --filter name=${CONTAINER} --format '[verify] {{.Names}} {{.Status}}'"
        echo "[verify] running commit: $($SSH_CMD librewxr "cat /opt/librewxr/src/DEPLOYED_COMMIT")"
        echo "=== LibreWXR deploy complete (${COMMIT}) ==="
        exit 0
    fi
    echo "[verify] health=${status_code}, waiting... (${i}/${HEALTH_TRIES})"
done
echo "[verify] health check never returned 200" >&2
echo "[verify] Check logs: ssh -F .local/ssh/config librewxr 'sudo docker logs ${CONTAINER} --since 5m'" >&2
exit 1
