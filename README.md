# strata-archlinux-pkg

Arch Linux packages for [lgse/strata](https://github.com/lgse/strata) ("the
best file manager on Linux"), built by GitHub Actions from the official
upstream release tarballs — **for every tag lgse/strata publishes**.

Each upstream tag (stable, `rc` and `nightly` alike) gets a matching release
in this repository containing ready-made `strata-bin-*-x86_64.pkg.tar.zst` and
`strata-bin-*-aarch64.pkg.tar.zst` packages plus a `SHA256SUMS.txt`, so you
can install Strata locally without an AUR helper:

```sh
sudo pacman -U strata-bin-<version>-1-x86_64.pkg.tar.zst
```

## Packages

One package is produced per upstream tag:

* **name:** `strata-bin` — same name as the AUR package, so `pacman -U`
  cleanly replaces an existing AUR `strata-bin` install (it also conflicts
  with `strata-rc-bin` and the from-source `strata` package)
* **contents:** the upstream release tarball, byte-identical binary
  (`!strip`), desktop entry, icon, FileManager1 service and licenses
* **version:** the upstream tag with `-` replaced by `_` in `pkgver`
  (`v1.0.1-nightly.20261015.1` → `pkgver=1.0.1_nightly.20261015.1`), because
  makepkg forbids hyphens in `pkgver`
* **update channel:** recorded in
  `/usr/share/strata/install-source.toml` (`stable`, `rc` or `nightly`,
  derived from the tag), which tells the app that pacman owns the install —
  updates go through your package manager, not Strata's built-in updater

## How CI works

`.github/workflows/package.yml` runs three jobs:

1. **find-releases** — queries the `lgse/strata` releases API and selects the
   tags that publish tarballs for both architectures but do not yet have a
   release in this repository (the existing releases here are the state)
2. **package** — for every selected tag × architecture, in an
   `archlinux:base-devel` container:
   * `scripts/sync-pkgbuild.sh` rewrites `pkgver`/`_releasever`, downloads
     the upstream `.sha256` assets and records the release channel
   * `makepkg --cleanbuild --syncdeps` builds the package
   * `namcap` lints it, and CI verifies the installed paths plus that the
     packaged binary is byte-identical to the upstream artifact
3. **release** — attaches the packages and a `SHA256SUMS.txt` to a release
   named after the upstream tag (created if missing, refreshed with
   `--clobber` otherwise); `rc`/`nightly` tags are marked as pre-releases

Triggers:

* **schedule** (hourly): packages every newly published upstream tag — this
  is what makes it "every tag released", with no manual step
* **workflow_dispatch**: on demand, with `target` set to `latest`, `all`, or
  one or more explicit tags (e.g. `v1.0.0 v1.0.1`) — explicit tags are
  rebuilt even if already packaged
* **push** to `main` (when `PKGBUILD`, `scripts/**` or the workflow change):
  re-runs the pipeline for the latest upstream release

Notes:

* Both architectures build on plain x86_64 runners: `strata-bin` repacks an
  upstream prebuilt tarball (there is no compilation), so the aarch64 flavor
  is produced by overriding `CARCH` in a copy of `makepkg.conf` — and CI
  still byte-compares the packaged binary against upstream's aarch64
  tarball. No arm runners needed, so this also works on private forks.
* Scheduled workflows stop firing after ~60 days without repository activity;
  re-enable or trigger manually if the project goes quiet.
* A run is capped at 25 releases at a time (`MAX_PACKAGES`), draining the
  backlog oldest-first; the next scheduled run picks up the rest.

## Building locally

On any Arch-based machine (no container needed):

```sh
./scripts/build-local.sh              # build the version pinned in the PKGBUILD
./scripts/build-local.sh v1.0.0       # sync the PKGBUILD to a tag, then build
sudo pacman -U ./strata-bin-*.pkg.tar.zst
```

On non-Arch hosts the script falls back to an `archlinux:base-devel`
container via podman or docker (set `CONTAINER=podman|docker` to force one,
`CONTAINER=none` to force makepkg, `NO_DEPS=1` to skip installing runtime
dependencies).

You can also drive the pieces yourself:

```sh
./scripts/sync-pkgbuild.sh v1.0.0     # point the PKGBUILD at an upstream tag
makepkg -si                           # build and install
./scripts/pending-releases.sh all     # what would CI package next?
```

## Repository layout

| Path                          | Purpose                                          |
| ----------------------------- | ------------------------------------------------ |
| `PKGBUILD`                    | the `strata-bin` package, synced to a tag        |
| `scripts/sync-pkgbuild.sh`    | point the PKGBUILD at any upstream tag           |
| `scripts/pending-releases.sh` | find upstream tags not packaged yet (CI matrix)  |
| `scripts/publish-release.sh`  | attach packages to per-tag releases              |
| `scripts/build-local.sh`      | build the package locally (makepkg or container) |
| `.github/workflows/package.yml` | the CI pipeline                                |
