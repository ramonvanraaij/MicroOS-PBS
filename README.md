# 🛡️ MicroOS-PBS: Proxmox Backup Server on MicroOS

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ramonvanraaij/microos-pbs?label=GitHub%20Release&style=flat-square)](https://github.com/ramonvanraaij/microos-pbs/releases)
[![Auto-Build PBS Container](https://github.com/ramonvanraaij/microos-pbs/actions/workflows/pbs-auto-build.yml/badge.svg?style=flat-square)](https://github.com/ramonvanraaij/microos-pbs/actions/workflows/pbs-auto-build.yml)
[![GitHub Container Registry](https://img.shields.io/badge/GHCR-latest-blue?logo=github&style=flat-square)](https://github.com/ramonvanraaij/microos-pbs/pkgs/container/microos-pbs)

This repository provides a specialized build system and deployment configuration for running **Proxmox Backup Server (PBS)** as a high-performance container on **OpenSUSE MicroOS** using **Podman Quadlets**.

---

## 🚀 Overview

This setup builds a Podman image for PBS using official Proxmox repositories and deploys it to a MicroOS host. It supports two distinct build and deployment strategies to accommodate both automated CI/CD and direct host-level control.

### ✨ Key Features
*   **🏗️ Immutable Infrastructure:** Designed specifically for OpenSUSE MicroOS.
*   **⚙️ Systemd Integration:** Native management via Podman Quadlet (`.container` units).
*   **🛠️ Dual Build Strategy:** Supports direct host builds (`build_on_microos.bash`) and automated GitHub Actions.
*   **📂 NFS Support:** Interactive setup for NFS-backed datastores with automated systemd mount generation.
*   **📦 Registry Support:** Official builds published to GitHub Container Registry (GHCR).

---

## ⚡ Performance Note

The build process is streamlined using pre-compiled packages from Proxmox Trixie repositories.

*   **Target Hardware:** Lenovo ThinkCentre M92p Tiny (Intel i5-3470T (4) @ 3.60 GHz).
*   **Estimated Build Time:** ~2-5 minutes (package-based).

---

## 📋 Prerequisites

*   **Target Host:** OpenSUSE MicroOS with `podman` enabled.
*   **Dependencies:** `nfs-utils` (for NFS) and `screen` (for build persistence) are required.
*   **Quick Install:** Run the following on your host:
    ```bash
    transactional-update pkg install nfs-utils screen && sync && sleep 5 && reboot
    ```

---

## 🚢 Deployment Options

### ⚡ Option A: Use Automated GHCR Image (Fastest)
Deploy using the image automatically built and published by GitHub Actions:
1.  **Run the setup script:**
    ```bash
    ./setup_microos.bash
    ```
2.  **Follow the wizard:** The setup will guide you through networking and storage configuration.

### 🛠️ Option B: Build Directly on MicroOS Host (Control)
If you prefer to compile the image directly on your target hardware:
1.  **Run the build script:**
    ```bash
    ./build_on_microos.bash
    ```
    This packs the current repo and triggers a build on the host, producing `localhost/proxmox-backup-server:latest`.
2.  **Run the setup script:**
    ```bash
    ./setup_microos.bash
    ```

---

## ⚙️ Configuration

*   **🖥️ Web UI:** `https://<microos-ip>:8007`
*   **🔑 Default Login:** `admin@pbs` / `pbspbs`

### 📂 Storage Paths
| Purpose | Host Path | Container Path |
| :--- | :--- | :--- |
| **Config** | `/var/lib/config/pbs` | `/etc/proxmox-backup` |
| **Data** | *Configurable* (e.g., `/var/mnt/pbs_datastore`) | `/var/lib/proxmox-backup` |
| **Logs** | `/var/log/pbs` | `/var/log/proxmox-backup` |

---

## 🔄 CI/CD Pipeline

The project includes a robust GitHub Actions workflow (`.github/workflows/pbs-auto-build.yml`) that:
1.  **Monitors Upstream:** Checks `git://git.proxmox.com` daily for new PBS releases.
2.  **Auto-Updates:** Syncs the `VERSION` file in the repository.
3.  **Distributes:** Builds and pushes new images to GHCR at `ghcr.io/ramonvanraaij/microos-pbs`.

---

## 🤝 Credits & Maintenance

Developed and maintained by **[Rámon van Raaij](https://ramon.vanraaij.eu)** (2026).

This project is an extensive refactor and specialization for MicroOS/Podman based on the [original work](https://github.com/ayufan/pve-backup-server-dockerfiles) by Kamil Trzciński (2020-2025).

*   **🦋 Bluesky:** [@ramonvanraaij.nl](https://bsky.app/profile/ramonvanraaij.nl)
*   **🐙 GitHub:** [@ramonvanraaij](https://github.com/ramonvanraaij)
*   **🌐 Website:** [ramon.vanraaij.eu](https://ramon.vanraaij.eu)

---

## ☕ Buy me a Coffee

If you found this project helpful, informative, or if it saved you some time, consider supporting my work! Your support motivates me to keep building and sharing.

*   **💳 [Bunq.me](https://bunq.me/ramonvanraaij)** (iDeal, Bancontact, Cards)
*   **🅿️ [PayPal](http://paypal.me/ramonvanraaij)**

Thank you for your support! ❤️
