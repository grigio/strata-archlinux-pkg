# Maintainer: strata-archlinux-pkg contributors
#
# Arch Linux package for lgse/strata, built from the official release
# tarballs. The version/checksum fields below are kept in sync with an
# upstream release tag by scripts/sync-pkgbuild.sh (run manually or by
# .github/workflows/package.yml for every tag lgse/strata publishes).

pkgname=strata-bin
pkgver=1.0.0
pkgrel=1
# Raw upstream tag without the leading "v"; the tarball URL is derived from it.
_releasever=1.0.0
pkgdesc="A fast, keyboard-first file manager for Linux"
arch=('x86_64' 'aarch64')
url="https://github.com/lgse/strata"
license=('MIT' 'LicenseRef-UnRAR')
depends=(
  'bubblewrap'
  'fontconfig'
  'glibc>=2.39'
  'gstreamer>=1.20'
  'gst-plugins-base'
  'gtk4>=4.12'
  'gtksourceview5'
  'gvfs'
  'poppler-glib'
)
optdepends=(
  'ffmpeg: video previews'
  'ffmpegthumbnailer: video thumbnails'
  'gst-libav: additional media format playback'
  'gst-plugins-good: media playback in previews'
  'gvfs-smb: SMB network locations'
  'imagemagick: RAW image previews'
  'libraw: RAW image previews when ImageMagick is unavailable'
  'squashfs-tools: AppImage icon thumbnails'
  'xdg-terminal-exec: preferred Open in Terminal launcher (AUR)'
)
provides=("strata=${pkgver}")
conflicts=('strata' 'strata-rc-bin')
# Preserve byte identity with the upstream release artifact.
options=('!strip' '!debug')
source_x86_64=("${url}/releases/download/v${_releasever}/strata-${_releasever}-x86_64-unknown-linux-gnu.tar.gz")
source_aarch64=("${url}/releases/download/v${_releasever}/strata-${_releasever}-aarch64-unknown-linux-gnu.tar.gz")
sha256sums_x86_64=('e15095a201165132a88032df15ecbeab795a13d6cacc4ebb943e276c35ff492e')
sha256sums_aarch64=('c89d6631f5f4a7b194bd7ba46108b5a3088f2d4823539e3af38c3022e32d1bd0')

package() {
  local dist="${srcdir}/strata-${_releasever}-${CARCH}-unknown-linux-gnu"

  install -Dm755 "${dist}/strata" "${pkgdir}/usr/bin/strata"
  install -Dm644 "${dist}/LICENSE" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
  # Older release archives predate bundled UnRAR.
  if [[ -f "${dist}/UnRAR.txt" ]]; then
    install -Dm644 "${dist}/UnRAR.txt" "${pkgdir}/usr/share/licenses/${pkgname}/UnRAR.txt"
  fi
  install -Dm644 "${dist}/THIRD_PARTY_LICENSES.md" \
    "${pkgdir}/usr/share/licenses/${pkgname}/THIRD_PARTY_LICENSES.md"

  if [[ -f "${dist}/io.github.lgse.Strata.desktop" ]]; then
    install -Dm644 "${dist}/io.github.lgse.Strata.desktop" \
      "${pkgdir}/usr/share/applications/io.github.lgse.Strata.desktop"
    install -Dm644 "${dist}/io.github.lgse.Strata.svg" \
      "${pkgdir}/usr/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg"
  else
    warning "Strata ${_releasever} ships no desktop entry or application icon; installing without a launcher."
  fi

  if [[ -f "${dist}/io.github.lgse.Strata.FileManager1.service" ]]; then
    install -Dm644 "${dist}/io.github.lgse.Strata.FileManager1.service" \
      "${pkgdir}/usr/share/strata/io.github.lgse.Strata.FileManager1.service"
  fi

  # Tells the running app that a package manager owns this install, so
  # updates go through pacman instead of the built-in self-updater.
  # The "channel" and "alternate_package" lines are rewritten by
  # scripts/sync-pkgbuild.sh when packaging pre-release tags.
  install -Dm644 /dev/stdin "${pkgdir}/usr/share/strata/install-source.toml" <<'MARKER'
manager = "pacman"
package = "strata-bin"
channel = "stable"
aur_helpers = ["yay", "paru", "pikaur", "trizen"]
alternate_package = "strata-rc-bin"
MARKER
}
