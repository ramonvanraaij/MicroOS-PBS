#!/usr/bin/env bash
# release.bash
# =================================================================
# Internal Build Engine for Proxmox Backup Server Container
#
# Copyright (c) 2026 Rámon van Raaij
# License: MIT
# Author: Rámon van Raaij | Bluesky: @ramonvanraaij.nl | GitHub: https://github.com/ramonvanraaij | Website: https://ramon.vanraaij.eu
# Repo: https://github.com/ramonvanraaij/microos-pbs
#
# This script provides the core container build logic used by both
# local and remote build processes.
#
# Usage:
# ./release.bash <tag> [build-image] [push-image] [deploy <remote>]
# =================================================================

if [[ $# -le 1 ]]; then
  echo "$0: usage <tag> [build-image] [push-image]"
  exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/"

IMAGE_TAG="$1"
shift

set -o errexit -o nounset -o pipefail -o xtrace

VERSION="${VERSION:-$(cat VERSION)}"
ARCH="amd64" # Default to amd64 for MicroOS

if [[ "$(uname -m)" == "aarch64" ]]; then
  ARCH="arm64"
fi

case "$ARCH" in
  arm64)
    IMAGE_PREFIX="arm64v8/"
    TARGET_PLATFORM="linux/arm64/v8"
    ;;
  amd64)
    IMAGE_PREFIX=""
    TARGET_PLATFORM="linux/amd64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

RELEASE_IMAGE_TAG="$IMAGE_TAG"

DOCKER_CMD="docker"
if command -v podman &> /dev/null; then
  DOCKER_CMD="podman"
fi

container_build() {
  $DOCKER_CMD build \
    --build-arg=ARCH="$ARCH" \
    --build-arg=VERSION="$VERSION" \
    --build-arg=IMAGE_PREFIX="$IMAGE_PREFIX" \
    --platform="$TARGET_PLATFORM" \
    "$@"
}

for i; do
  case "$i" in
    build-image)
      container_build --file=dockerfiles/Dockerfile.build --target="release_env" --tag="$RELEASE_IMAGE_TAG" "."
      ;;

    push-image)
      $DOCKER_CMD push "$RELEASE_IMAGE_TAG"
      ;;
      
    deploy)
      # Helper to save and copy to remote
      # usage: ./release.bash <tag> deploy <remote_host>
      # This requires the image to be built first
      shift
      REMOTE="$1"
      if [[ -z "$REMOTE" ]]; then echo "Remote host required for deploy"; exit 1; fi
      echo ">> Deploying to $REMOTE..."
      $DOCKER_CMD save "$RELEASE_IMAGE_TAG" | ssh "$REMOTE" "$DOCKER_CMD load"
      ;;

    *)
      echo "Unsure what to do with '$1'."
      exit 1
      ;;
  esac
done