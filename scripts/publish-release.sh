#!/usr/bin/env bash
# Attach built strata-bin packages to per-tag GitHub releases.
#
# Usage:
#   publish-release.sh '<matrix json>'
#
# where <matrix> is the JSON array produced by pending-releases.sh
# ([{"tag": "v1.0.0", "version": "1.0.0", "pkgver": "1.0.0", ...}, ...]).
#
# For each entry, all strata-bin-<pkgver>-<arch>.pkg.tar.zst files found in
# the dist directory are attached to a release named after the upstream tag
# (created if missing, updated with --clobber otherwise), together with a
# SHA256SUMS.txt file. Pre-release tags (rc/nightly/...) are marked as
# pre-releases.
#
# Environment:
#   GITHUB_REPOSITORY  target repository (required by gh)
#   GH_TOKEN           token with contents:write (required by gh)
#   DIST_DIR           directory holding the packages (default: dist)
#   DRY_RUN=1          print what would happen instead of publishing
set -euo pipefail

dist=${DIST_DIR:-dist}
matrix=${1:?usage: publish-release.sh '<matrix json>'}

die() {
  echo "error: $*" >&2
  exit 1
}

if [[ ${DRY_RUN:-0} != 1 ]]; then
  command -v gh >/dev/null 2>&1 || die "the gh CLI is required"
  [[ -n ${GITHUB_REPOSITORY:-} ]] || die "GITHUB_REPOSITORY is not set"
fi

while IFS=$'\t' read -r tag pkgver prerelease; do
  [[ -n $tag ]] || continue

  shopt -s nullglob
  packages=("$dist"/strata-bin-"$pkgver"-*.pkg.tar.zst)
  shopt -u nullglob
  ((${#packages[@]})) || die "no packages for ${tag} (pkgver ${pkgver}) found in ${dist}/"

  sums_dir=$(mktemp -d)
  (cd "$dist" && sha256sum strata-bin-"$pkgver"-*.pkg.tar.zst) \
    >"${sums_dir}/SHA256SUMS.txt"

  notes=$(cat <<EOF
Arch Linux packages for [lgse/strata ${tag}](https://github.com/lgse/strata/releases/tag/${tag}),
built by GitHub Actions from the official upstream release tarballs (checksum-verified
against the upstream \`.sha256\` assets).

## Install

Download the package for your architecture and install it:

\`\`\`sh
sudo pacman -U strata-bin-${pkgver}-1-x86_64.pkg.tar.zst   # or the aarch64 package
\`\`\`

The package conflicts with the AUR \`strata-bin\`/\`strata-rc-bin\` packages and the
from-source \`strata\` package; pacman will offer to remove them.

Upstream release notes: <https://github.com/lgse/strata/releases/tag/${tag}>
EOF
)

  if [[ ${DRY_RUN:-0} == 1 ]]; then
    echo "DRY_RUN: would attach ${#packages[@]} package(s) + SHA256SUMS.txt to release ${tag}"
    continue
  fi

  if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
    echo "Release ${tag} exists; refreshing its assets"
    gh release upload "$tag" "${packages[@]}" "${sums_dir}/SHA256SUMS.txt" \
      --repo "$GITHUB_REPOSITORY" --clobber
  else
    args=(
      release create "$tag" "${packages[@]}" "${sums_dir}/SHA256SUMS.txt"
      --repo "$GITHUB_REPOSITORY"
      --title "strata ${tag}"
      --notes "$notes"
    )
    [[ $prerelease == true ]] && args+=(--prerelease)
    gh "${args[@]}"
    echo "Created release ${tag}"
  fi

  rm -rf "$sums_dir"
done < <(jq -r '.[] | [.tag, .pkgver, (.prerelease | tostring)] | @tsv' <<<"$matrix")
