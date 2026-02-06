#!/usr/bin/env bash
# local_cleanup.bash
# =================================================================
# Clean up the local build and test artifacts.
#
# Copyright (c) 2026 Rámon van Raaij
# License: MIT
# Author: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
# Repo: https://github.com/ramonvanraaij/microos-pbs
#
# This script stops and removes the test containers, the dedicated
# test network, and the local test data directories.
#
# Usage:
# ./local_cleanup.bash
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

CONTAINER_NAME="pbs-test-env"
CLIENT_NAME="pbs-test-client"
NETWORK_NAME="pbs-test-net"
TEST_DIR="$SCRIPT_DIR/test-environment"
IMAGE_NAME="proxmox-backup-server-local"

echo ">> Stopping and removing containers..."
$DOCKER_CMD stop "$CONTAINER_NAME" "$CLIENT_NAME" >/dev/null 2>&1
$DOCKER_CMD rm "$CONTAINER_NAME" "$CLIENT_NAME" >/dev/null 2>&1

echo ">> Removing network $NETWORK_NAME..."
$DOCKER_CMD network rm "$NETWORK_NAME" >/dev/null 2>&1

echo ">> Removing test data folder: $TEST_DIR..."
# sudo might be needed if PBS created files with UID 34
if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR" || sudo rm -rf "$TEST_DIR"
fi

read -p ">> Do you also want to remove the local images? [y/N]: " REMOVE_IMAGES
if [[ "$REMOVE_IMAGES" =~ ^[Yy]$ ]]; then
    echo ">> Removing local images..."
    $DOCKER_CMD rmi "$IMAGE_NAME:latest" >/dev/null 2>&1 || true
    # Find all versions of this image
    $DOCKER_CMD images --format "{{.Repository}}:{{.Tag}}" | grep "$IMAGE_NAME" | xargs $DOCKER_CMD rmi >/dev/null 2>&1 || true
fi

echo ">> Cleanup complete."
