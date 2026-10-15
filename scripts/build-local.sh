#!/usr/bin/env bash
# Build the strata-bin Arch package on this machine.
#
# Usage:
#   scripts/build-local.sh              # build the version pinned in PKGBUILD
#   scripts/build-local.sh v1.0.0       # sync the PKGBUILD to v1.0.0 first
#
# Builds with makepkg when available (Arch host), otherwise falls back to an
# archlinux:base-devel container via podman/docker.
#
# Environment:
#   CONTAINER=podman|docker|none  force a container engine
#   NO_DEPS=1                     skip installing runtime deps (--syncdeps)
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ${1:-} == v* ]]; then
  ./scripts/sync-pkgbuild.sh "$1"
fi

engine=${CONTAINER:-}
if [[ -z $engine ]]; then
  if command -v makepkg >/dev/null 2>&1; then
    engine=none
  elif command -v podman >/dev/null 2>&1; then
    engine=podman
  elif command -v docker >/dev/null 2>&1; then
    engine=docker
  else
    echo "error: neither makepkg nor podman/docker found" >&2
    exit 1
  fi
fi

flags=(--cleanbuild --noconfirm)
if [[ ${NO_DEPS:-0} != 1 ]]; then
  flags+=(--syncdeps)
fi

if [[ $engine == none ]]; then
  if [[ $EUID -eq 0 ]]; then
    echo "error: run as your normal user, not root (makepkg refuses to run as root)" >&2
    exit 1
  fi
  makepkg "${flags[@]}"
else
  "$engine" run --rm -v "$PWD":/build -w /build archlinux:base-devel bash -ec '
    pacman -Syu --noconfirm --needed base-devel >/dev/null
    useradd --create-home builder
    printf "builder ALL=(ALL) NOPASSWD: ALL\n" > /etc/sudoers.d/builder
    chown -R builder /build
    su builder -c "makepkg --cleanbuild --syncdeps --noconfirm"
  '
fi

echo
echo "Built packages:"
ls -1 strata-bin-*.pkg.tar.zst
echo
echo "Install with: sudo pacman -U ./<package>"
