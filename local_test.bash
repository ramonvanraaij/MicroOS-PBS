#!/usr/bin/env bash
# local_test.bash
# =================================================================
# Deploy the local PBS container for testing.
#
# Copyright (c) 2026 Rámon van Raaij
# License: MIT
# Author: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
# Repo: https://github.com/ramonvanraaij/microos-pbs
#
# This script deploys a self-contained PBS test environment using 
# a dedicated Podman network and a separate Debian client to 
# perform a 'real' multi-container backup verification.
#
# Usage:
# ./local_test.bash
# =================================================================

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Detection of container tool
if [[ -n "${CI:-}" ]]; then
    DOCKER_CMD="docker"
elif command -v podman &> /dev/null; then
    DOCKER_CMD="podman"
else
    DOCKER_CMD="docker"
fi

# Allow overriding the image name via environment variable for CI
IMAGE_NAME="${TEST_IMAGE_NAME:-proxmox-backup-server-local}"
VERSION=$(cat VERSION | sed 's/^v//')
# Handle case where VERSION might already be the full tag
if [[ "$IMAGE_NAME" == *":"* ]]; then
    FULL_IMAGE="$IMAGE_NAME"
else
    FULL_IMAGE="$IMAGE_NAME:$VERSION"
fi

CONTAINER_NAME="pbs-test-env"
CLIENT_NAME="pbs-test-client"
NETWORK_NAME="pbs-test-net"
TEST_DIR="$SCRIPT_DIR/test-environment"

echo ">> Preparing test environment in $TEST_DIR..."
mkdir -p "$TEST_DIR/config"
mkdir -p "$TEST_DIR/data"
mkdir -p "$TEST_DIR/logs"

# Ensure network exists
if ! $DOCKER_CMD network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo ">> Creating network $NETWORK_NAME..."
    $DOCKER_CMD network create "$NETWORK_NAME"
fi

# Check if containers already exist
for c in "$CONTAINER_NAME" "$CLIENT_NAME"; do
    if $DOCKER_CMD ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
        echo ">> Container $c already exists. Stopping and removing..."
        $DOCKER_CMD stop "$c" >/dev/null 2>&1 || true
        $DOCKER_CMD rm "$c" >/dev/null 2>&1 || true
    fi
done

echo ">> Starting PBS Server $CONTAINER_NAME..."
$DOCKER_CMD run -d \
    --name "$CONTAINER_NAME" \
    --net "$NETWORK_NAME" \
    --pull=never \
    -p 8007:8007 \
    --tmpfs /run \
    -v "$TEST_DIR/config:/etc/proxmox-backup" \
    -v "$TEST_DIR/data:/var/lib/proxmox-backup" \
    -v "$TEST_DIR/logs:/var/log/proxmox-backup" \
    "$FULL_IMAGE"

echo "------------------------------------------------"
echo ">> PBS Server is starting up!"
echo ">> URL: https://localhost:8007"
echo ">> Default Login: admin@pbs / pbspbs"

echo ">> Injecting local test datastore configuration..."
sleep 5
# Inject config
$DOCKER_CMD cp dockerfiles/pbs/datastore.cfg.local "$CONTAINER_NAME":/etc/proxmox-backup/datastore.cfg
$DOCKER_CMD exec -u root "$CONTAINER_NAME" chown backup:backup /etc/proxmox-backup/datastore.cfg

# Initialize chunk store structure manually (much faster than manager if already exists)
echo ">> Initializing chunk store structure (0000-ffff)..."
$DOCKER_CMD exec -u root "$CONTAINER_NAME" bash -c '
    mkdir -p /var/lib/proxmox-backup/.chunks
    cd /var/lib/proxmox-backup/.chunks
    printf "%04x\n" {0..65535} | xargs mkdir -p
'
$DOCKER_CMD exec -u root "$CONTAINER_NAME" chown -R backup:backup /var/lib/proxmox-backup

# Get fingerprint from server
echo ">> Retrieving Server Fingerprint..."
FINGERPRINT=""
attempt=0
while [ -z "$FINGERPRINT" ] && [ $attempt -lt 10 ]; do
    FINGERPRINT=$($DOCKER_CMD exec "$CONTAINER_NAME" proxmox-backup-manager cert info 2>/dev/null | grep Fingerprint | awk '{print $NF}' || echo "")
    [ -z "$FINGERPRINT" ] && sleep 2
    attempt=$((attempt+1))
done

if [ -z "$FINGERPRINT" ]; then
    echo ">> Error: Could not retrieve server fingerprint."
    exit 1
fi
echo ">> Server Fingerprint: $FINGERPRINT"

echo ">> Starting Test Client (Debian Trixie)..."
$DOCKER_CMD run -d \
    --name "$CLIENT_NAME" \
    --net "$NETWORK_NAME" \
    --pull=never \
    debian:trixie-slim \
    sleep infinity

echo ">> Installing Proxmox Backup Client in client container..."
$DOCKER_CMD exec -u root "$CLIENT_NAME" bash -c "
    apt-get update && apt-get install -y wget ca-certificates gnupg
    wget -qO - https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg > /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg
    echo 'deb http://download.proxmox.com/debian/pbs trixie pbs-no-subscription' > /etc/apt/sources.list.d/pbs.list
    apt-get update && apt-get install -y proxmox-backup-client
"

echo ">> Waiting for PBS API to become ready (Network: $NETWORK_NAME)..."
MAX_RETRIES=30
COUNT=0
until $DOCKER_CMD exec -e PBS_PASSWORD="pbspbs" -e PBS_FINGERPRINT="$FINGERPRINT" "$CLIENT_NAME" \
    proxmox-backup-client status \
    --repository "admin@pbs@$CONTAINER_NAME:8007:test-datastore" > /dev/null 2>&1 || [ $COUNT -eq $MAX_RETRIES ]; do
    sleep 2
    COUNT=$((COUNT + 1))
    echo -n "."
done
echo ""

if [ $COUNT -eq $MAX_RETRIES ]; then
    echo ">> Error: PBS API did not become ready in time."
    $DOCKER_CMD logs "$CONTAINER_NAME" | tail -n 20
    exit 1
fi

echo ">> PBS API is ready. Running 'real' multi-container backup test..."

# Create a dummy file in the client container
$DOCKER_CMD exec "$CLIENT_NAME" dd if=/dev/urandom of=/tmp/client_data.bin bs=1M count=10 status=none

echo ">> Uploading backup from client to server..."
$DOCKER_CMD exec -e PBS_PASSWORD="pbspbs" -e PBS_FINGERPRINT="$FINGERPRINT" "$CLIENT_NAME" \
    proxmox-backup-client backup real-client-test.img:/tmp/client_data.bin \
    --repository "admin@pbs@$CONTAINER_NAME:8007:test-datastore" \
    --crypt-mode none \
    || (echo ">> Backup failed!"; exit 1)

echo ">> 'Real' Backup successful!"
echo ">> You can verify it at: https://localhost:8007"
echo "------------------------------------------------"
echo ">> Logs: $DOCKER_CMD logs -f $CONTAINER_NAME"
echo ">> Cleanup: ./local_cleanup.bash"
echo "------------------------------------------------"
