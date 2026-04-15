#!/usr/bin/env bash
# check_upstream.bash
# =================================================================
# Detect the latest upstream Proxmox Backup Server package version
#
# Copyright (c) 2026 Rámon van Raaij
# License: MIT
# Author: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
#
# This script queries the Proxmox APT repository to determine the
# latest available package version of proxmox-backup-server,
# including the Debian revision suffix (e.g., 4.1.7-1).
#
# The APT repository is the authoritative source: git tags may appear
# days before packages are actually published, so checking the repo
# ensures we only trigger builds when installable packages exist.
#
# It performs the following actions:
# 1. Fetches the binary-amd64 Packages index from the Proxmox
#    no-subscription repository
# 2. Extracts all versions of the proxmox-backup-server package
# 3. Returns the highest version using dpkg-style sorting
#
# Usage:
#   ./scripts/check_upstream.bash
#
# Output:
#   Prints the latest version string (e.g., "4.1.7-1") to stdout.
#   Exits with code 1 if the version cannot be determined.
# =================================================================
set -euo pipefail

# --- Configuration ---
PACKAGES_URL="http://download.proxmox.com/debian/pbs/dists/trixie/pbs-no-subscription/binary-amd64/Packages"

# --- Main ---

# Fetch all versions of the proxmox-backup-server package and select
# the highest one. Uses sort -V (version sort) which handles Debian
# version strings (X.Y.Z-N) correctly.
LATEST=$(curl -sf "$PACKAGES_URL" \
    | awk '/^Package: proxmox-backup-server$/{found=1; next} found && /^Version: /{print $2; found=0}' \
    | sort -V \
    | tail -n 1)

if [ -z "$LATEST" ]; then
    echo "Error: Could not determine latest upstream package version." >&2
    exit 1
fi

echo "$LATEST"
