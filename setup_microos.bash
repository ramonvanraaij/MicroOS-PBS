#!/bin/bash
# setup_microos.bash
# =================================================================
# Interactive Setup for Proxmox Backup Server on MicroOS
#
# Copyright (c) 2026 Rámon van Raaij
# Fork Maintainer: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
# =================================================================

set -e

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

# --- NFS Configuration ---
echo ""
echo "--- NFS Datastore Configuration ---"
read -p "Use NFS for the PBS Datastore? [y/N]: " USE_NFS
if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    read -p "NFS Server IP: " NFS_IP
    read -p "NFS Export Path (e.g. /volume1/backups): " NFS_PATH
    if [[ -z "$NFS_IP" || -z "$NFS_PATH" ]]; then echo "NFS details required"; exit 1; fi
fi

echo ""
echo ">> Target: $REMOTE_TARGET"
echo ">> NFS Enabled: ${USE_NFS:-n}"
echo "----------------------------------"

# 1. Transfer Quadlet file
echo ">> Preparing Quadlet definition..."
QUADLET_TMP=$(mktemp /tmp/pbs-quadlet.XXXXXX)
cp quadlet/proxmox-backup-server.container "$QUADLET_TMP"

if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    # Add dependency on NFS mount to Quadlet
    sed -i "/^After=/ s/$/ var-lib-data-pbs.mount/" "$QUADLET_TMP"
    sed -i "/^\\[Unit\\]/ a Requires=var-lib-data-pbs.mount" "$QUADLET_TMP"
    
    # Create Mount Unit
    MOUNT_UNIT_TMP=$(mktemp /tmp/pbs-mount.XXXXXX)
    cat <<EOF > "$MOUNT_UNIT_TMP"
[Unit]
Description=NFS Mount for PBS Datastore
After=network-online.target

[Mount]
What=${NFS_IP}:${NFS_PATH}
Where=/var/lib/data/pbs
Type=nfs
Options=nfsvers=3,defaults

[Install]
WantedBy=multi-user.target
EOF
fi

# 2. Build Remote Script
REMOTE_SCRIPT="
set -e

echo '>> [Remote] Checking for NFS tools...'
if [[ \"$USE_NFS\" =~ ^[Yy]$ ]]; then
    if ! rpm -q nfs-utils &>/dev/null; then
        echo 'ERROR: nfs-utils is not installed on the MicroOS host.'
        echo 'Please run: sudo transactional-update pkg install nfs-utils && sudo reboot'
        exit 1
    fi
fi

echo '>> [Remote] Creating and setting permissions for directories...'
mkdir -p /var/lib/config/pbs /var/lib/data/pbs /var/log/pbs
chown -R 34:34 /var/lib/config/pbs /var/lib/data/pbs /var/log/pbs

echo '>> [Remote] Installing Quadlet...'
mv /tmp/proxmox-backup-server.container /etc/containers/systemd/
"

if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    REMOTE_SCRIPT="$REMOTE_SCRIPT
echo '>> [Remote] Installing NFS Mount Unit...'
mv /tmp/var-lib-data-pbs.mount /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now var-lib-data-pbs.mount
"
fi

REMOTE_SCRIPT="$REMOTE_SCRIPT
echo '>> [Remote] Configuring Firewall (Port 8007)...'
firewall-cmd --permanent --zone=public --add-port=8007/tcp
firewall-cmd --reload

echo '>> [Remote] Reloading Systemd and Starting Service...'
systemctl daemon-reload
systemctl start proxmox-backup-server
"

# 3. Execute Deployment
echo ">> Uploading files..."
cat "$QUADLET_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/proxmox-backup-server.container"
if [[ "$USE_NFS" =~ ^[Yy]$ ]]; then
    cat "$MOUNT_UNIT_TMP" | $SSH_PIPE_CMD "$REMOTE_TARGET" "cat > /tmp/var-lib-data-pbs.mount"
fi

echo ">> Executing setup commands (You will be prompted for sudo password once)..."
$SSH_CMD "$REMOTE_TARGET" "sudo bash -c \"$REMOTE_SCRIPT\""

# Cleanup local temps
rm -f "$QUADLET_TMP" "$MOUNT_UNIT_TMP"

echo ">> Setup complete. PBS should be reachable at https://$REMOTE_HOST:8007"