# MicroOS-PBS: Proxmox Backup Server on MicroOS (Podman Quadlet)

This repository provides a specialized build system and deployment configuration for running **Proxmox Backup Server (PBS)** as a container on **OpenSUSE MicroOS** using **Podman Quadlets**.

This is a fork of the [original project](https://github.com/ayufan/pve-backup-server-dockerfiles) by Kamil Trzciński, adapted specifically for immutable infrastructure and Podman-based environments.

## Overview

This setup builds a Docker/Podman image for PBS from source (including dependencies) and deploys it to a MicroOS host. It uses systemd generator (Quadlet) to manage the container service, ensuring seamless integration with the host OS.

**Key Features:**
*   **Immutable Infrastructure:** Designed specifically for OpenSUSE MicroOS.
*   **Systemd Integration:** Managed via Quadlet (`.container` unit).
*   **Persistence:** Config and Data stored in `/var/lib/config/pbs` and `/var/lib/data/pbs`.
*   **NFS Support:** Interactive setup for NFS-backed datastores.
*   **Resource Efficient:** Optimized for low-power hardware like the Lenovo ThinkCentre Tiny.

## Performance Note

Building this image from source is a heavy process as it compiles numerous Proxmox dependencies and the PBS Rust codebase.

**Hardware:** Lenovo ThinkCentre M92p Tiny (Intel Core i5-3470T (4) @ 3.60 GHz)
**Estimated Build Time:** ~45-60 minutes.

The build process is fully automated and runs inside a container on the target MicroOS host to ensure perfect compatibility and avoid local dependency issues.

## Prerequisites

*   **Build Host:** Any machine with SSH access to the target.
*   **Target Host:** OpenSUSE MicroOS with `podman` enabled.
*   **NFS (Optional):** If using an NFS datastore, ensure `nfs-utils` is installed on MicroOS (`sudo transactional-update pkg install nfs-utils && reboot`).

## Getting Started

### 1. Build the Image
Run the remote build script to compile and tag the image directly on your MicroOS host:

```bash
./build_on_microos.bash
```

This will produce `localhost/proxmox-backup-server:latest`.

### 2. Setup the Container
Run the setup script to configure directories, firewall, and deploy the Quadlet:

```bash
./setup_microos.bash
```

The script will ask if you want to use an NFS mount for your datastore.

## Configuration

*   **Web UI:** `https://<microos-ip>:8007`
*   **Default Login:** `admin` / `pbspbs`

### Storage Paths
*   **Config:** `/var/lib/config/pbs` -> `/etc/proxmox-backup`
*   **Data:** `/var/lib/data/pbs` -> `/var/lib/proxmox-backup` (Datastore)
*   **Logs:** `/var/log/pbs` -> `/var/log/proxmox-backup`

## Author

Originally built by Kamil Trzciński, 2020-2025.
Specialized fork for MicroOS maintained by Rámon van Raaij (2026).
- **Bluesky:** [@ramonvanraaij.nl](https://bsky.app/profile/ramonvanraaij.nl)
- **GitHub:** [ramonvanraaij](https://github.com/ramonvanraaij)
- **Website:** [ramon.vanraaij.eu](https://ramon.vanraaij.eu)

## Buy me a Coffee

<p><strong>Buy me a coffee 🙂</strong><br>If you found this fork helpful, informative, or if it saved or made you some money, consider buying me a coffee. Your support means a lot and motivates me to keep writing.<br>You can do so via <a href="https://bunq.me/ramonvanraaij" rel="nofollow">bunq.me</a> (bunq, iDeal, Bankcontact and Credit- or Debit cards) or <a href="http://paypal.me/ramonvanraaij" rel="nofollow">PayPal</a> (PayPal and Credit- or Debit cards). Thank you!</p>