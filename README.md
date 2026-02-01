# MicroOS-PBS: Proxmox Backup Server on MicroOS (Podman Quadlet)

This repository provides a specialized build system and deployment configuration for running **Proxmox Backup Server (PBS)** as a container on **OpenSUSE MicroOS** using **Podman Quadlets**.

This is a fork of the [original project](https://github.com/ayufan/pve-backup-server-dockerfiles) by Kamil Trzciński, adapted specifically for immutable infrastructure and Podman-based environments.

## Overview

This setup builds a Podman image for PBS using official Proxmox repositories and deploys it to a MicroOS host. It uses systemd generator (Quadlet) to manage the container service, ensuring seamless integration with the host OS.

**Key Features:**
*   **Immutable Infrastructure:** Designed specifically for OpenSUSE MicroOS.
*   **Systemd Integration:** Managed via Quadlet (`.container` unit).
*   **Persistence:** Config and Data stored in `/var/lib/config/pbs` and configurable datastore paths.
*   **NFS Support:** Interactive setup for NFS-backed datastores with automated systemd mount generation.
*   **Fast & Efficient:** Uses pre-compiled packages from Proxmox Trixie repositories.

## Performance Note

While the build process is now streamlined using pre-compiled packages, the initial setup and container initialization are optimized for low-power hardware.

**Hardware Profile:** Lenovo ThinkCentre M92p Tiny (Intel Core i5-3470T (4) @ 3.60 GHz).
**Estimated Build Time:** ~2-5 minutes (using packages).

## Prerequisites

*   **Build Host:** Any machine with SSH access to the target.
*   **Target Host:** OpenSUSE MicroOS with `podman` enabled.
*   **Dependencies:** `nfs-utils` (for NFS datastores) and `screen` (for build persistence) are required. Run the following on the host:
    ```bash
    transactional-update pkg install nfs-utils screen && sync && sleep 5 && reboot
    ```

## Getting Started

### 1. Build the Image
Run the remote build script to pack the repository and trigger a build directly on your MicroOS host:

```bash
./build_on_microos.bash
```

This will produce `localhost/proxmox-backup-server:latest`.

### 2. Setup the Container
Run the setup script to configure directories, firewall, and deploy the Quadlet:

```bash
./setup_microos.bash
```

The script will interactively ask for network, hostname, datastore name, and optional NFS mount details.

## Configuration

*   **Web UI:** `https://<microos-ip>:8007`
*   **Default Login:** `admin@pbs` / `pbspbs`

### Storage Paths
*   **Config:** `/var/lib/config/pbs` -> `/etc/proxmox-backup`
*   **Data:** Configurable (e.g., `/var/mnt/pbs_datastore`) -> `/var/lib/proxmox-backup`
*   **Logs:** `/var/log/pbs` -> `/var/log/proxmox-backup`

## Author

Originally built by Kamil Trzciński, 2020-2025.
Specialized fork for MicroOS maintained by Rámon van Raaij (2026).
- **Bluesky:** [@ramonvanraaij.nl](https://bsky.app/profile/ramonvanraaij.nl)
- **GitHub:** [ramonvanraaij](https://github.com/ramonvanraaij)
- **Website:** [ramon.vanraaij.eu](https://ramon.vanraaij.eu)

## Buy me a Coffee

<p><strong>Buy me a coffee 🙂</strong><br>If you found this fork helpful, informative, or if it saved or made you some money, consider buying me a coffee. Your support means a lot and motivates me to keep writing.<br>You can do so via <a href="https://bunq.me/ramonvanraaij" rel="nofollow">bunq.me</a> (bunq, iDeal, Bankcontact and Credit- or Debit cards) or <a href="http://paypal.me/ramonvanraaij" rel="nofollow">PayPal</a> (PayPal and Credit- or Debit cards). Thank you!</p>
