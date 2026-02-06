#!/usr/bin/env bash
# setup_microos.bash
# =================================================================
# Interactive Setup for Proxmox Backup Server on MicroOS
#
# Copyright (c) 2026 Rámon van Raaij
# License: MIT
# Author: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
# Repo: https://github.com/ramonvanraaij/MicroOS-PBS
#
# This script performs an interactive setup of Proxmox Backup Server
# on an OpenSUSE MicroOS host using Podman Quadlets.
# =================================================================

set -o errexit -o nounset -o pipefail

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

# --- Instance Configuration ---
echo ""
echo "--- Instance Configuration ---"
read -p "Container Name [proxmox-backup-server]: " PBS_CONTAINER_NAME
PBS_CONTAINER_NAME=${PBS_CONTAINER_NAME:-proxmox-backup-server}

read -p "Container Port [8007]: " PBS_PORT
PBS_PORT=${PBS_PORT:-8007}

read -p "Host Config Path [/var/lib/config/pbs]: " HOST_CONFIG_PATH
HOST_CONFIG_PATH=${HOST_CONFIG_PATH:-/var/lib/config/pbs}

read -p "Host Logs Path [/var/log/pbs]: " HOST_LOGS_PATH
HOST_LOGS_PATH=${HOST_LOGS_PATH:-/var/log/pbs}

# --- Image Configuration ---
echo ""
echo "--- Container Image ---"
echo "1) Local (localhost/proxmox-backup-server:latest)"
echo "2) GHCR (ghcr.io/ramonvanraaij/proxmox-backup-server:latest)"
read -p "Select image source [1]: " IMAGE_CHOICE
case "$IMAGE_CHOICE" in
    2) PBS_IMAGE="ghcr.io/ramonvanraaij/proxmox-backup-server:latest" ;;
    *) PBS_IMAGE="localhost/proxmox-backup-server:latest" ;;
esac

# --- Network Configuration ---
echo ""
echo "--- Podman Network ---"
read -p "Podman Network [host]: " PODMAN_NETWORK
PODMAN_NETWORK=${PODMAN_NETWORK:-host}

if [[ "$PODMAN_NETWORK" == "host" && "$PBS_PORT" != "8007" ]]; then
    echo "WARNING: Port mapping ($PBS_PORT:8007) is NOT supported in 'host' network mode."
    echo "The service will still listen on port 8007 on the host."
    read -p "Switch to 'bridge' network instead? [Y/n]: " SWITCH_NET
    if [[ ! "$SWITCH_NET" =~ ^[Nn]$ ]]; then
        PODMAN_NETWORK="bridge"
        echo ">> Switched to bridge network."
    fi
fi

# --- PBS Hostname ---
echo ""
read -p "PBS Hostname [MicroOS-PBS]: " PBS_HOSTNAME
PBS_HOSTNAME=${PBS_HOSTNAME:-MicroOS-PBS}

# --- NFS Configuration ---
echo ""
echo "--- NFS Datastore Configuration ---"
read -p "Use NFS for the PBS Datastore? [y/N]: " USE_NFS
if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    read -p "NFS Server IP: " NFS_IP
    read -p "NFS Export Path (e.g. /volume1/backups): " NFS_PATH
    read -p "Local Mount Point [/var/mnt/pbs_datastore]: " LOCAL_MOUNT_POINT
    LOCAL_MOUNT_POINT=${LOCAL_MOUNT_POINT:-/var/mnt/pbs_datastore}
    
    read -p "Datastore Name [default]: " DATASTORE_NAME
    DATASTORE_NAME=${DATASTORE_NAME:-default}
else
    LOCAL_MOUNT_POINT="/var/lib/data/pbs"
    DATASTORE_NAME=""
fi

echo ""
echo ">> Target: $REMOTE_TARGET"
echo ">> Instance: $PBS_CONTAINER_NAME (Port: $PBS_PORT)"
echo ">> Image: $PBS_IMAGE"
echo ">> Network: $PODMAN_NETWORK"
echo ">> Hostname: $PBS_HOSTNAME"
echo ">> Config Path: $HOST_CONFIG_PATH"
echo ">> Logs Path: $HOST_LOGS_PATH"
if [[ -n "$DATASTORE_NAME" ]]; then echo ">> Datastore: $DATASTORE_NAME (NFS)"; fi
echo ">> Data Path: $LOCAL_MOUNT_POINT"
echo "----------------------------------"

# 1. Prepare Files Locally
echo ">> Preparing Quadlet and Setup Script..."
QUADLET_TMP=$(mktemp /tmp/pbs-quadlet.XXXXXX)
cp quadlet/proxmox-backup-server.container "$QUADLET_TMP"

# Update Quadlet
sed -i "s/^ContainerName=.*/ContainerName=$PBS_CONTAINER_NAME/" "$QUADLET_TMP"
sed -i "s|^Image=.*|Image=$PBS_IMAGE|" "$QUADLET_TMP"
sed -i "s/^Network=.*/Network=$PODMAN_NETWORK/" "$QUADLET_TMP"
sed -i "s/^PodmanArgs=--hostname=.*/PodmanArgs=--hostname=$PBS_HOSTNAME/" "$QUADLET_TMP"
sed -i "s/^PublishPort=.*/PublishPort=$PBS_PORT:8007/" "$QUADLET_TMP"
sed -i "s|Volume=/var/lib/config/pbs|Volume=${HOST_CONFIG_PATH}|" "$QUADLET_TMP"
sed -i "s|Volume=/var/log/pbs|Volume=${HOST_LOGS_PATH}|" "$QUADLET_TMP"
sed -i "s|Volume=/var/lib/data/pbs|Volume=${LOCAL_MOUNT_POINT}|" "$QUADLET_TMP"

if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    LOCAL_MOUNT_UNIT_NAME=$(systemd-escape --path --suffix=mount "$LOCAL_MOUNT_POINT")
    sed -i "s/^After=.*/& $LOCAL_MOUNT_UNIT_NAME/" "$QUADLET_TMP"
    sed -i "/^\[Unit\]/ a Requires=$LOCAL_MOUNT_UNIT_NAME" "$QUADLET_TMP"
    
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

# 2. Generate Remote Bash Script
REMOTE_SETUP_SCRIPT_TMP=$(mktemp /tmp/pbs-remote-setup.XXXXXX)
cat <<EOF > "$REMOTE_SETUP_SCRIPT_TMP"
#!/bin/bash
set -o errexit -o nounset -o pipefail
PBS_CONTAINER_NAME="$PBS_CONTAINER_NAME"
HOST_CONFIG_PATH="$HOST_CONFIG_PATH"
HOST_LOGS_PATH="$HOST_LOGS_PATH"
LOCAL_MOUNT_POINT="$LOCAL_MOUNT_POINT"
DATASTORE_NAME="$DATASTORE_NAME"
USE_NFS="$USE_NFS"
PBS_PORT="$PBS_PORT"

echo '>> [Remote] Creating directories...'
mkdir -p "\$HOST_CONFIG_PATH" "\$HOST_LOGS_PATH" "\$LOCAL_MOUNT_POINT"

if [[ "\$USE_NFS" =~ ^[Yy]$ ]] && [ ! -f "\$HOST_CONFIG_PATH/datastore.cfg" ]; then
    echo ">> [Remote] Initializing datastore.cfg..."
    echo "datastore: \$DATASTORE_NAME" > "\$HOST_CONFIG_PATH/datastore.cfg"
    echo "    path /var/lib/proxmox-backup" >> "\$HOST_CONFIG_PATH/datastore.cfg"
    chown 34:34 "\$HOST_CONFIG_PATH/datastore.cfg"
fi

echo '>> [Remote] Setting permissions (34:34)...'
chown -R 34:34 "\$HOST_CONFIG_PATH" "\$HOST_LOGS_PATH"

echo '>> [Remote] Installing Quadlet...'
mv /tmp/pbs.container "/etc/containers/systemd/\$PBS_CONTAINER_NAME.container"
chown root:root "/etc/containers/systemd/\$PBS_CONTAINER_NAME.container"

if [[ "\$USE_NFS" =~ ^[Yy]$ ]]; then
    R_MOUNT_UNIT_NAME=\$(systemd-escape --path --suffix=mount "\$LOCAL_MOUNT_POINT")
    mv /tmp/pbs-mount.mount "/etc/systemd/system/\$R_MOUNT_UNIT_NAME"
    systemctl daemon-reload
    systemctl enable --now "\$R_MOUNT_UNIT_NAME"
fi

echo ">> [Remote] Configuring Firewall (Port \$PBS_PORT)..."
firewall-cmd --permanent --zone=public --add-port=\$PBS_PORT/tcp
firewall-cmd --reload

echo '>> [Remote] Reloading and Restarting Service...'
systemctl daemon-reload
systemctl restart "\$PBS_CONTAINER_NAME" || systemctl start "\$PBS_CONTAINER_NAME"

echo '>> [Remote] Waiting for service to become active...'
attempt=0
while [ \$attempt -lt 60 ]; do
    STATUS=\$(systemctl is-active "\$PBS_CONTAINER_NAME")
    [ "\$STATUS" == "active" ] && echo ">> Success!" && exit 0
    [ "\$STATUS" == "failed" ] && systemctl status "\$PBS_CONTAINER_NAME" --no-pager && exit 1
    sleep 2; attempt=\$((attempt+1))
done
EOF

# 3. Upload and Execute
echo ">> Uploading files..."
cat "$QUADLET_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/pbs.container"
cat "$REMOTE_SETUP_SCRIPT_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/pbs-setup.sh"
[[ "$USE_NFS" =~ ^[Yy]$ ]] && cat "$MOUNT_UNIT_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/pbs-mount.mount"

$SSH_CMD "$REMOTE_TARGET" "sudo bash /tmp/pbs-setup.sh && rm /tmp/pbs-setup.sh"
rm -f "$QUADLET_TMP" "${MOUNT_UNIT_TMP:-}" "$REMOTE_SETUP_SCRIPT_TMP"

echo ">> Setup complete. Accessible at https://$REMOTE_HOST:$PBS_PORT"
