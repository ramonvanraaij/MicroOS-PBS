#!/usr/bin/env bash
# local_build.bash
# =================================================================
# Build Proxmox Backup Server Image locally
#
# Copyright (c) 2026 Rámon van Raaij
# License: MIT
# Author: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
# Repo: https://github.com/ramonvanraaij/microos-pbs
#
# This script builds the PBS container image locally using Podman
# or Docker, mimicking the GitHub Actions build environment.
#
# Usage:
# ./local_build.bash
# =================================================================

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Detection of container tool
DOCKER_CMD="docker"
if command -v podman &> /dev/null; then
    DOCKER_CMD="podman"
fi

IMAGE_NAME="proxmox-backup-server-local"
VERSION=$(cat VERSION | sed 's/^v//')

echo ">> Using $DOCKER_CMD to build $IMAGE_NAME:$VERSION"

$DOCKER_CMD build \
    --file dockerfiles/Dockerfile.build \
    --target release_env \
    --build-arg VERSION="$VERSION" \
    --tag "$IMAGE_NAME:$VERSION" \
    --tag "$IMAGE_NAME:latest" \
    .

echo "------------------------------------------------"
echo ">> Build complete: $IMAGE_NAME:$VERSION"
echo ">> You can now run ./local_test.bash to start it."
echo "------------------------------------------------"
