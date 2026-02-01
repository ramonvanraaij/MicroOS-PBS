# MicroOS-PBS: Proxmox Backup Server on MicroOS (Podman Quadlet)

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ramonvanraaij/microos-pbs?label=GitHub%20Release)](https://github.com/ramonvanraaij/microos-pbs/releases)
[![Auto-Build PBS Container](https://github.com/ramonvanraaij/microos-pbs/actions/workflows/pbs-auto-build.yml/badge.svg)](https://github.com/ramonvanraaij/microos-pbs/actions/workflows/pbs-auto-build.yml)
[![GitHub Container Registry](https://img.shields.io/badge/GHCR-latest-blue?logo=github)](https://github.com/ramonvanraaij/microos-pbs/pkgs/container/microos-pbs)

This repository provides a specialized build system and deployment configuration for running **Proxmox Backup Server (PBS)** as a container on **OpenSUSE MicroOS** using **Podman Quadlets**.

This project is an extensive refactor and evolution of the [original work](https://github.com/ayufan/pve-backup-server-dockerfiles) by Kamil Trzciński, specialized for **OpenSUSE MicroOS** and **Podman Quadlets**.

## Overview

This setup builds a Podman image for PBS using official Proxmox repositories and deploys it to a MicroOS host. It supports two distinct build and deployment strategies to accommodate both automated CI/CD and direct host-level control.

**Key Features:**
*   **Immutable Infrastructure:** Designed specifically for OpenSUSE MicroOS.
*   **Systemd Integration:** Managed via Quadlet (`.container` unit).
*   **Dual Build Strategy:** Supports direct host builds (`build_on_microos.bash`) and automated GitHub Actions.
*   **NFS Support:** Interactive setup for NFS-backed datastores with automated systemd mount generation.
*   **Registry Support:** Official builds published to GitHub Container Registry (GHCR).

## Performance Note

The build process is streamlined using pre-compiled packages from Proxmox Trixie repositories.

**Target Hardware:** Lenovo ThinkCentre M92p Tiny (Intel Core i5-3470T (4) @ 3.60 GHz).

**Estimated Build Time:** ~2-5 minutes (package-based).

## Prerequisites

*   **Target Host:** OpenSUSE MicroOS with `podman` enabled.
*   **Dependencies:** `nfs-utils` (for NFS datastores) and `screen` (for build persistence) are required. Run the following on the host:
    ```bash
    transactional-update pkg install nfs-utils screen && sync && sleep 5 && reboot
    ```

## Deployment Options

### Option A: Use Automated GHCR Image (Fastest)
Deploy using the image automatically built and published by GitHub Actions:
1.  Run the setup script:
    ```bash
    ./setup_microos.bash
    ```
2.  When prompted for configuration, the setup will guide you through networking and storage.

### Option B: Build Directly on MicroOS Host (Control)
If you prefer to compile the image directly on your target hardware:
1.  Run the build script:
    ```bash
    ./build_on_microos.bash
    ```
    This packs the current repo and triggers a build on the host, producing `localhost/proxmox-backup-server:latest`.
2.  Run the setup script:
    ```bash
    ./setup_microos.bash
    ```

## Configuration

*   **Web UI:** `https://<microos-ip>:8007`
*   **Default Login:** `admin@pbs` / `pbspbs`

### Storage Paths
*   **Config:** `/var/lib/config/pbs` -> `/etc/proxmox-backup`
*   **Data:** Configurable (e.g., `/var/mnt/pbs_datastore`) -> `/var/lib/proxmox-backup`
*   **Logs:** `/var/log/pbs` -> `/var/log/proxmox-backup`

## CI/CD Pipeline

The project includes a GitHub Actions workflow (`.github/workflows/pbs-auto-build.yml`) that:
1.  Checks `git://git.proxmox.com` daily for new PBS releases.
2.  Auto-updates the `VERSION` file in the repository.
3.  Builds and pushes the new image to GHCR at `ghcr.io/ramonvanraaij/microos-pbs`.

## Credits & Maintenance

This project is developed and maintained by **Rámon van Raaij** (2026). It is an extensive refactor and specialization for MicroOS/Podman based on the [original project](https://github.com/ayufan/pve-backup-server-dockerfiles) by Kamil Trzciński (2020-2025).

**Maintainer Info:**
- **Bluesky:** [@ramonvanraaij.nl](https://bsky.app/profile/ramonvanraaij.nl)
- **GitHub:** [ramonvanraaij](https://github.com/ramonvanraaij)
- **Website:** [ramon.vanraaij.eu](https://ramon.vanraaij.eu)

## Buy me a Coffee

<p><strong>Buy me a coffee 🙂</strong><br>If you found this fork helpful, informative, or if it saved or made you some money, consider buying me a coffee. Your support means a lot and motivates me to keep writing.<br>You can do so via <a href="https://bunq.me/ramonvanraaij" rel="nofollow">bunq.me</a> (bunq, iDeal, Bankcontact and Credit- or Debit cards) or <a href="http://paypal.me/ramonvanraaij" rel="nofollow">PayPal</a> (PayPal and Credit- or Debit cards). Thank you!</p>