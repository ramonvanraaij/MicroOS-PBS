#!/bin/bash
# build_on_microos.bash
# =================================================================
# Build Proxmox Backup Server Image remotely on MicroOS
#
# Copyright (c) 2026 Rámon van Raaij
# Fork Maintainer: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
#
# This script packs the current repository and performs a remote 
# build using Podman on an OpenSUSE MicroOS host.
# =================================================================

set -e

# --- Interactive Configuration ---
echo "--- MicroOS Connection Details ---"
read -p "MicroOS Host (IP or hostname): " REMOTE_HOST
if [[ -z "$REMOTE_HOST" ]]; then echo "Remote host required"; exit 1; fi

read -p "MicroOS SSH Port [22]: " REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}

read -p "MicroOS SSH Username: " REMOTE_USER
if [[ -z "$REMOTE_USER" ]]; then echo "Remote user required"; exit 1; fi

read -p "Use a Jumphost? [y/N]: " USE_JUMP
if [[ "$USE_JUMP" =~ ^[Yy]$ ]]; then
    read -p "Jumphost IP: " JUMP_HOST
    read -p "Jumphost Port [22]: " JUMP_PORT
    JUMP_PORT=${JUMP_PORT:-22}
    read -p "Jumphost Username: " JUMP_USER
    
    JUMP_STR="${JUMP_USER}@${JUMP_HOST}:${JUMP_PORT}"
    SSH_OPTS="-o ServerAliveInterval=60 -p ${REMOTE_PORT} -o ProxyJump=${JUMP_STR}"
else
    SSH_OPTS="-o ServerAliveInterval=60 -p ${REMOTE_PORT}"
fi

REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
BUILD_DIR="/var/tmp/pbs-build"

echo "----------------------------------"
echo ">> Target: $REMOTE_TARGET"
echo ">> Build Dir: $BUILD_DIR"
echo "----------------------------------"

# 1. Pack Source
echo ">> Packing repository (excluding .git and build artifacts)..."
TAR_FILE=$(mktemp /tmp/pbs-source.XXXXXX.tar.gz)
trap 'rm -f "$TAR_FILE"' EXIT
tar -czf "$TAR_FILE" --exclude='./.git' --exclude='./build' --exclude='./node_modules' .

# 2. Upload
echo ">> Uploading source code to $REMOTE_HOST..."
ssh ${SSH_OPTS} "$REMOTE_TARGET" "mkdir -p $BUILD_DIR"
cat "$TAR_FILE" | ssh ${SSH_OPTS} "$REMOTE_TARGET" "cat > $BUILD_DIR/source.tar.gz"

# 3. Remote Build Execution
echo ">> Executing Remote Build (You will be prompted for sudo password)..."

# We use a single-quoted heredoc for the variable to prevent local expansion.
# This passes the script literally to the remote bash.
REMOTE_SCRIPT='
set -e
BUILD_DIR="/var/tmp/pbs-build"
LOG_FILE="$BUILD_DIR/build.log"
cd "$BUILD_DIR"

echo ">> Extracting source..."
tar -xzf source.tar.gz

echo ">> Checking Podman..."
if command -v podman >/dev/null; then
    echo ">> Podman found: $(command -v podman)"
else
    echo ">> Podman MISSING!"
    exit 1
fi

echo ">> Checking for screen..."
if ! command -v screen >/dev/null; then
    echo "ERROR: screen is not installed on the MicroOS host."
    echo "Please run: sudo transactional-update pkg install screen && sudo reboot"
    exit 1
fi

echo ">> Preparing Build Script..."
chmod +x release.bash

# Command to run inside screen
BUILD_CMD="./release.bash proxmox-backup-server build-image"

echo ">> Starting Build in Screen Session pbs-build..."
echo ">> Logs will be written to $LOG_FILE"

# Start detached screen session, logging to file
screen -dmS pbs-build bash -c "$BUILD_CMD > $LOG_FILE 2>&1"

echo ">> Build started in background."
echo ">> Tailing log file (Ctrl+C to stop watching, build will continue)..."
sleep 2
tail -f $LOG_FILE
'

# Pass the script securely - Run with SUDO for System Quadlet compatibility
ssh -t ${SSH_OPTS} "$REMOTE_TARGET" "sudo bash -c '$REMOTE_SCRIPT'"

echo ">> Done. The image is now available on $REMOTE_HOST."
