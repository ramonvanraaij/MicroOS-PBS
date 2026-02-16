# 🛡️ MicroOS-PBS: Proxmox Backup Server on MicroOS

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ramonvanraaij/MicroOS-PBS?label=GitHub%20Release&style=flat-square)](https://github.com/ramonvanraaij/MicroOS-PBS/releases)
[![Auto-Build PBS Container](https://github.com/ramonvanraaij/MicroOS-PBS/actions/workflows/pbs-auto-build.yml/badge.svg?style=flat-square)](https://github.com/ramonvanraaij/MicroOS-PBS/actions/workflows/pbs-auto-build.yml)
[![GitHub Container Registry](https://img.shields.io/badge/GHCR-latest-blue?logo=github&style=flat-square)](https://github.com/ramonvanraaij/MicroOS-PBS/pkgs/container/proxmox-backup-server)

This repository provides a specialized build system and deployment configuration for running **Proxmox Backup Server (PBS)** as a high-performance container. While optimized for **OpenSUSE MicroOS** using **Podman Quadlets**, it is fully compatible with standard **Docker** and **Podman (Compose)** environments.

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
*   **Reference Build:** Lenovo Yoga Pro 9 16IMH9 (Intel Core Ultra 9 185H (22) @ 5.10 GHz).
*   **Measured Build Time:** ~1 minute 40 seconds (clean build).

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
If you prefer to build the image directly on your target hardware:
1.  **Run the build script:**
    ```bash
    ./build_on_microos.bash
    ```
    This packs the current repo and triggers a build on the host, producing `localhost/proxmox-backup-server:latest`.
2.  **Run the setup script:**
    ```bash
    ./setup_microos.bash
    ```

### 🛠️ Option C: Local Development & Testing (Podman/Docker)
The local scripts and configuration are designed to work seamlessly with both **Podman** and **Docker**.

#### 1. Automated Test Suite (Recommended)
This script builds the image, sets up a private network, and performs a real backup verification using a separate client container:
1.  **Build locally:** `./local_build.bash`
2.  **Run multi-container test:** `./local_test.bash`
3.  **Clean up:** `./local_cleanup.bash`

#### 2. Local Execution via Docker Compose
For a standard persistent local setup, use the provided `docker-compose.yml`:
1.  **Start the server:**
    ```bash
    docker compose up -d
    # or
    podman-compose up -d
    ```
2.  **Access Web UI:** `https://localhost:8007` (admin@pbs / pbspbs)

#### 3. Manual Local Execution
```bash
docker run -d \
    --name pbs-local \
    -p 8007:8007 \
    --tmpfs /run \
    -v $(pwd)/data/config:/etc/proxmox-backup \
    -v $(pwd)/data/datastores:/var/lib/proxmox-backup \
    ghcr.io/ramonvanraaij/proxmox-backup-server:latest
```

---

## 🔄 Branch Strategy & Release Flow

The project uses a structured release flow to ensure stability:

1.  **Develop Branch (`develop`):** Daily automated checks monitor upstream Proxmox releases. If a new version is detected, a **Release Candidate (`-RC`)** is automatically created and published from this branch.
2.  **Testing & Verification:** Changes are tested on the `develop` branch. Manual builds on `develop` generate unique date-versioned images for isolated verification.
3.  **Main Branch (`main`):** Once verified, `develop` is merged into `main` (squashed). Running a manual "Force" build on `main` finalizes the **Stable** release and tags it as `latest`.

---

## ⚙️ Configuration

*   **🖥️ Web UI:** `https://<microos-ip>:8007`
*   **🔑 Default Login:** `admin@pbs` / `pbspbs`

### 📂 Storage Paths
| Purpose | Host Path | Container Path |
| :--- | :--- | :--- |
| **Config** | *Configurable* (Default: `/var/lib/config/pbs`) | `/etc/proxmox-backup` |
| **Data** | *Configurable* (Default: `/var/lib/data/pbs`) | `/var/lib/proxmox-backup` |
| **Logs** | *Configurable* (Default: `/var/log/pbs`) | `/var/log/proxmox-backup` |

---

## 🔄 CI/CD Pipeline

The project includes a robust GitHub Actions workflow (`.github/workflows/pbs-auto-build.yml`) that:
1.  **Monitors Upstream:** Checks `git://git.proxmox.com` daily for new PBS releases.
2.  **Auto-Updates:** Syncs the `VERSION` file in the repository.
3.  **Distributes:** Builds and pushes new images to GHCR at `ghcr.io/ramonvanraaij/proxmox-backup-server`.

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
