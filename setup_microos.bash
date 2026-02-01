#!/usr/bin/env bash
# setup_microos.bash
# =================================================================
# Interactive Setup for Proxmox Backup Server on MicroOS
#
# Copyright (c) 2026 Rámon van Raaij
# License: MIT
# Author: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
#
# This script performs an interactive setup of Proxmox Backup Server
# on an OpenSUSE MicroOS host using Podman Quadlets.
#
# It performs the following actions:
# 1. Prompts for host, network, hostname, and NFS configuration.
# 2. Uploads the Quadlet definition and a remote setup script.
# 3. Configures directories, permissions, firewall, and NFS mounts.
# 4. Restarts and verifies the pbs service startup.
#
# Usage:
# sudo ./setup_microos.bash
# =================================================================

set -o errexit -o nounset -o pipefail

# --- Root Check ---
# Removed per user request to allow running without local sudo (ssh handles it)

# --- Interactive Configuration ---
echo "--- MicroOS Host Configuration ---"
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
    SSH_OPTS="-p ${REMOTE_PORT} -o ProxyJump=${JUMP_STR}"
else
    SSH_OPTS="-p ${REMOTE_PORT}"
fi

REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
SSH_CMD="ssh -t ${SSH_OPTS}"
SSH_PIPE_CMD="ssh ${SSH_OPTS}"

# --- Network Configuration ---
echo ""
echo "--- Podman Network ---"
read -p "Podman Network [host]: " PODMAN_NETWORK
PODMAN_NETWORK=${PODMAN_NETWORK:-host}

# --- PBS Hostname ---
echo ""
read -p "PBS Hostname [MicroOS-PBS]: " PBS_HOSTNAME
PBS_HOSTNAME=${PBS_HOSTNAME:-MicroOS-PBS}

# --- NFS Configuration ---
echo ""
echo "--- NFS Datastore Configuration ---"
echo "Configure an existing NFS share to be used as the PBS Datastore."
echo "This will be mounted on the host and then passed into the container."
read -p "Use NFS for the PBS Datastore? [y/N]: " USE_NFS
if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    read -p "NFS Server IP: " NFS_IP
    read -p "NFS Export Path (e.g. /volume1/backups): " NFS_PATH
    read -p "Local Mount Point [/var/mnt/pbs_datastore]: " LOCAL_MOUNT_POINT
    LOCAL_MOUNT_POINT=${LOCAL_MOUNT_POINT:-/var/mnt/pbs_datastore}
    
    read -p "Datastore Name [default]: " DATASTORE_NAME
    DATASTORE_NAME=${DATASTORE_NAME:-default}
    
    if [[ -z "$NFS_IP" || -z "$NFS_PATH" ]]; then echo "NFS details required"; exit 1; fi
else
    LOCAL_MOUNT_POINT="/var/lib/data/pbs"
    DATASTORE_NAME=""
fi

echo ""
echo ">> Target: $REMOTE_TARGET"
echo ">> Network: $PODMAN_NETWORK"
echo ">> Hostname: $PBS_HOSTNAME"
if [[ -n "$DATASTORE_NAME" ]]; then
    echo ">> Datastore: $DATASTORE_NAME (NFS)"
fi
echo ">> Data Path: $LOCAL_MOUNT_POINT"
echo "----------------------------------"

# 1. Prepare Files Locally
echo ">> Preparing Quadlet and Setup Script..."
QUADLET_TMP=$(mktemp /tmp/pbs-quadlet.XXXXXX)
cp quadlet/proxmox-backup-server.container "$QUADLET_TMP"

# Update Network
sed -i "s/^Network=.*/Network=$PODMAN_NETWORK/" "$QUADLET_TMP"

# Update Hostname (Using PodmanArgs for compatibility)
sed -i "s/^PodmanArgs=--hostname=.*/PodmanArgs=--hostname=$PBS_HOSTNAME/" "$QUADLET_TMP"

# Update Data Volume Path
sed -i "s|Volume=/var/lib/data/pbs|Volume=${LOCAL_MOUNT_POINT}|" "$QUADLET_TMP"

# Increase startup timeout
sed -i "s/^TimeoutStartSec=.*/TimeoutStartSec=300/" "$QUADLET_TMP"

if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    # Add dependency on NFS mount to Quadlet
    if command -v systemd-escape >/dev/null; then
        LOCAL_MOUNT_UNIT_NAME=$(systemd-escape --path --suffix=mount "$LOCAL_MOUNT_POINT")
    else
        LOCAL_MOUNT_UNIT_NAME=$(echo "${LOCAL_MOUNT_POINT#/}" | tr '/' '-').mount
    fi
    
    # Append unit name to After= line
    sed -i "s/^After=.*/& $LOCAL_MOUNT_UNIT_NAME/" "$QUADLET_TMP"
    
    # Add Requires= line after [Unit] header
    sed -i "/^\[Unit\]/a Requires=$LOCAL_MOUNT_UNIT_NAME" "$QUADLET_TMP"
    
    # Create Mount Unit
    MOUNT_UNIT_TMP=$(mktemp /tmp/pbs-mount.XXXXXX)
    cat <<EOF > "$MOUNT_UNIT_TMP"
[Unit]
Description=NFS Mount for PBS Datastore
After=network-online.target

[Mount]
What=${NFS_IP}:${NFS_PATH}
Where=${LOCAL_MOUNT_POINT}
Type=nfs
Options=nfsvers=3,defaults

[Install]
WantedBy=multi-user.target
EOF
fi

# 2. Generate Remote Bash Script (Self-contained)
REMOTE_SETUP_SCRIPT_TMP=$(mktemp /tmp/pbs-remote-setup.XXXXXX)

# Header with injected variables
cat <<EOF > "$REMOTE_SETUP_SCRIPT_TMP"
#!/bin/bash
set -e
USE_NFS="$USE_NFS"
LOCAL_MOUNT_POINT="$LOCAL_MOUNT_POINT"
DATASTORE_NAME="$DATASTORE_NAME"
EOF

# Main Body (Quoted Heredoc - No Expansion)
cat <<'EOF' >> "$REMOTE_SETUP_SCRIPT_TMP"

echo '>> [Remote] Checking for NFS tools...'
if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    if ! type -p mount.nfs >/dev/null; then
        echo 'ERROR: mount.nfs not found. NFS utils seem missing.'
        echo 'Please run: transactional-update pkg install nfs-utils && sync && sleep 5 && reboot'
        exit 1
    fi
fi

echo '>> [Remote] Creating directories...'
mkdir -p /var/lib/config/pbs /var/log/pbs "$LOCAL_MOUNT_POINT"

# Auto-configure datastore if missing and NFS is used
if [[ "$USE_NFS" =~ ^[Yy]$ ]] && [ ! -f /var/lib/config/pbs/datastore.cfg ]; then
    echo ">> [Remote] Initializing datastore.cfg with name: $DATASTORE_NAME..."
    echo "datastore: $DATASTORE_NAME" > /var/lib/config/pbs/datastore.cfg
    echo '    path /var/lib/proxmox-backup' >> /var/lib/config/pbs/datastore.cfg
    chown 34:34 /var/lib/config/pbs/datastore.cfg
fi

echo '>> [Remote] Setting permissions (Config/Logs only)...'
chown -R 34:34 /var/lib/config/pbs /var/log/pbs

echo '>> [Remote] Installing Quadlet...'
# mv as root from /tmp to /etc results in root-owned file
mv /tmp/proxmox-backup-server.container /etc/containers/systemd/
chown root:root /etc/containers/systemd/proxmox-backup-server.container

if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    echo '>> [Remote] Installing NFS Mount Unit...'
    
    # Calculate unit name ON REMOTE to match systemd expectation exactly
    if command -v systemd-escape >/dev/null; then
        R_MOUNT_UNIT_NAME=$(systemd-escape --path --suffix=mount "$LOCAL_MOUNT_POINT")
    else
        R_MOUNT_UNIT_NAME=$(echo "${LOCAL_MOUNT_POINT#/}" | tr '/' '-').mount
    fi
    
    # Display cleaner name
    DISPLAY_NAME=$(echo "$R_MOUNT_UNIT_NAME" | sed 's/\x2d/-/g')
    echo ">> [Remote] Mount Unit: $DISPLAY_NAME"
    
    mv /tmp/var-lib-data-pbs.mount "/etc/systemd/system/$R_MOUNT_UNIT_NAME"
    
    systemctl daemon-reload
    systemctl enable --now "$R_MOUNT_UNIT_NAME"
fi

echo '>> [Remote] Configuring Firewall (Port 8007)...'
firewall-cmd --permanent --zone=public --add-port=8007/tcp
firewall-cmd --reload

echo '>> [Remote] Reloading Systemd and Starting Service (This may take a while)...'
systemctl daemon-reload
systemctl restart proxmox-backup-server || systemctl start proxmox-backup-server

echo '>> [Remote] Waiting for service to become active...'
attempt=0
max_attempts=60
while [ $attempt -lt $max_attempts ]; do
    STATUS=$(systemctl is-active proxmox-backup-server)
    if [ "$STATUS" == "active" ]; then
        echo ">> Service started successfully!"
        exit 0
    elif [ "$STATUS" == "failed" ]; then
        echo ">> Service failed to start."
        systemctl status proxmox-backup-server --no-pager
        exit 1
    fi
    echo ">> Status: $STATUS. Waiting..."
    sleep 2
    attempt=$((attempt+1))
done

echo ">> WARNING: Service is still starting or status is unknown ($STATUS)."
exit 0
EOF

# 3. Upload Files
echo ">> Uploading files to $REMOTE_HOST..."
cat "$QUADLET_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/proxmox-backup-server.container"
cat "$REMOTE_SETUP_SCRIPT_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/pbs-setup.sh"

if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    cat "$MOUNT_UNIT_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/var-lib-data-pbs.mount"
fi

# 4. Execute Remote Setup
echo ">> Executing setup script (You will be prompted for sudo password once)..."
$SSH_CMD "$REMOTE_TARGET" "sudo bash /tmp/pbs-setup.sh && rm /tmp/pbs-setup.sh"

# Cleanup local temps
rm -f "$QUADLET_TMP" "$MOUNT_UNIT_TMP" "$REMOTE_SETUP_SCRIPT_TMP"

echo ">> Setup complete. PBS should be reachable at https://$REMOTE_HOST:8007"
echo ">> Default Login: admin@pbs / pbspbs"
