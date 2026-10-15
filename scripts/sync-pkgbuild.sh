#!/usr/bin/env bash
# Sync the PKGBUILD with an upstream lgse/strata release tag.
#
# Usage:
#   scripts/sync-pkgbuild.sh vX.Y.Z
#
# Rewrites pkgver/_releasever, the release tarball checksums (fetched from
# the upstream .sha256 assets, computed locally as a fallback) and the update
# channel recorded in the install-source.toml marker:
#
#   vX.Y.Z            -> channel "stable"
#   vX.Y.Z-rc.N       -> channel "rc"     (preview channel)
#   vX.Y.Z-nightly.*  -> channel "nightly"
#
# pkgver is the tag without the leading "v" with hyphens replaced by
# underscores, because makepkg forbids hyphens in pkgver. The exact upstream
# tag remains available to the packaged app via _releasever.
#
# Environment:
#   UPSTREAM_REPO  GitHub repo to package (default: lgse/strata)
#   PKGBUILD       path to the PKGBUILD  (default: PKGBUILD)
set -euo pipefail

UPSTREAM_REPO=${UPSTREAM_REPO:-lgse/strata}
PKGBUILD=${PKGBUILD:-PKGBUILD}

die() {
  echo "error: $*" >&2
  exit 1
}

tag=${1:-}
[[ $tag == v* ]] || die "usage: sync-pkgbuild.sh vX.Y.Z (got '${tag:-}')"
version=${tag#v}

# makepkg rejects colons, slashes, hyphens and whitespace in pkgver.
pkgver=${version//-/_}
[[ $pkgver != *[-:/[:space:]]* ]] ||
  die "sanitized pkgver '$pkgver' still contains characters makepkg forbids"

case $version in
  *nightly*) channel=nightly alternate_package='' desc_suffix=' (nightly channel)' ;;
  *-rc.*)    channel=rc      alternate_package='strata-bin' desc_suffix=' (preview channel)' ;;
  *)         channel=stable  alternate_package='strata-rc-bin' desc_suffix='' ;;
esac

base_url="https://github.com/${UPSTREAM_REPO}/releases/download/${tag}"

fetch_checksum() {
  local arch=$1 sum
  local asset="strata-${version}-${arch}-unknown-linux-gnu.tar.gz"

  if sum=$(curl -fsSL "${base_url}/${asset}.sha256" 2>/dev/null | awk 'NR == 1 { print $1 }') &&
    [[ $sum =~ ^[0-9a-f]{64}$ ]]; then
    printf '%s\n' "$sum"
    return
  fi

  echo "warning: ${asset}.sha256 is missing upstream; hashing the tarball directly" >&2
  curl -fsSL "${base_url}/${asset}" | sha256sum | awk '{ print $1 }'
}

sha_x86_64=$(fetch_checksum x86_64)
sha_aarch64=$(fetch_checksum aarch64)

# Keep the current pkgrel when re-syncing the same version so fixes can be
# released as pkgrel bumps; reset it to 1 when the version changes.
pkgrel=1
current_version=$(sed -n 's/^_releasever=//p' "$PKGBUILD")
if [[ $current_version == "$version" ]]; then
  pkgrel=$(sed -n 's/^pkgrel=//p' "$PKGBUILD")
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=${pkgrel}/" \
  -e "s/^_releasever=.*/_releasever=${version}/" \
  -e "s/^pkgdesc=.*/pkgdesc=\"A fast, keyboard-first file manager for Linux${desc_suffix}\"/" \
  -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('${sha_x86_64}')/" \
  -e "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('${sha_aarch64}')/" \
  -e "s/^channel = \".*\"/channel = \"${channel}\"/" \
  -e "s/^alternate_package = \".*\"/alternate_package = \"${alternate_package}\"/" \
  "$PKGBUILD"

bash -n "$PKGBUILD" || die "the synced PKGBUILD does not parse"
if command -v makepkg >/dev/null 2>&1; then
  makepkg --printsrcinfo >/dev/null || die "makepkg rejects the synced PKGBUILD"
fi

echo "Synced ${PKGBUILD} with ${tag}:"
echo "  pkgver=${pkgver} pkgrel=${pkgrel} channel=${channel}"
echo "  sha256sums_x86_64=('${sha_x86_64}')"
echo "  sha256sums_aarch64=('${sha_aarch64}')"
