#!/usr/bin/env bash
# Determine which lgse/strata releases still need an Arch package in this
# repository. A release is "pending" when upstream publishes the tarballs for
# it but this repository has no release with that tag yet.
#
# Usage:
#   pending-releases.sh all              # every pending release (default)
#   pending-releases.sh latest           # only the newest pending release
#   pending-releases.sh v1.0.0 [v1.0.1]  # explicit tag(s), even if packaged
#
# Environment:
#   UPSTREAM_REPO  GitHub repo to package          (default: lgse/strata)
#   SELF_REPO      this repository on GitHub       (default: $GITHUB_REPOSITORY;
#                                                   empty = no state check)
#   MAX_PACKAGES   cap per run, oldest first       (default: 25)
#   GITHUB_TOKEN   optional API token (raises rate limits)
#
# Prints the selected releases as a JSON array and, when $GITHUB_OUTPUT is
# set, writes the "matrix" and "has_work" outputs for GitHub Actions.
set -euo pipefail

UPSTREAM_REPO=${UPSTREAM_REPO:-lgse/strata}
SELF_REPO=${SELF_REPO:-${GITHUB_REPOSITORY:-}}
MAX_PACKAGES=${MAX_PACKAGES:-25}

die() {
  echo "error: $*" >&2
  exit 1
}

api() {
  local path=$1
  local -a auth=()
  [[ -n ${GITHUB_TOKEN:-} ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  curl -fsSL "${auth[@]}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com${path}"
}

# Fetch every page of a list endpoint.
api_all() {
  local path=$1 page=1 chunk length
  local out='[]'
  while :; do
    chunk=$(api "${path}?per_page=100&page=${page}")
    length=$(jq 'length' <<<"$chunk")
    out=$(jq -c -s 'add' <<<"${out}"$'\n'"${chunk}")
    ((length < 100)) && break
    page=$((page + 1))
  done
  printf '%s\n' "$out"
}

# Upstream releases that ship release tarballs for both supported
# architectures. pkgver is the version with hyphens replaced by underscores
# (makepkg forbids hyphens in pkgver).
candidates=$(api_all "/repos/${UPSTREAM_REPO}/releases" | jq -c '
  [.[]
   | select(.draft == false)
   | (.tag_name | ltrimstr("v")) as $v
   | (.assets | map(.name)) as $names
   | select(($names | index("strata-\($v)-x86_64-unknown-linux-gnu.tar.gz")) != null
        and ($names | index("strata-\($v)-aarch64-unknown-linux-gnu.tar.gz")) != null)
   | {
       tag: .tag_name,
       version: $v,
       pkgver: ($v | gsub("-"; "_")),
       prerelease: .prerelease
     }]')

# Tags this repository has already published a release for.
packaged='[]'
if [[ -n $SELF_REPO ]]; then
  packaged=$(api_all "/repos/${SELF_REPO}/releases" | jq -c '[.[].tag_name]')
fi

pending=$(jq -c --argjson packaged "$packaged" \
  '[.[] | select(.tag as $tag | ($packaged | index($tag) | not))]' <<<"$candidates")

mode=${1:-all}
selected='[]'
case $mode in
  all)
    selected=$pending
    ;;
  latest)
    selected=$(jq -c '.[0:1]' <<<"$pending")
    ;;
  v*)
    for tag in "$@"; do
      entry=$(jq -c --arg tag "$tag" 'map(select(.tag == $tag))[0]' <<<"$candidates")
      [[ $entry != null ]] ||
        die "upstream release '$tag' not found (or it does not publish tarballs for both architectures)"
      selected=$(jq -c --argjson entry "$entry" '. + [$entry]' <<<"$selected")
    done
    ;;
  *)
    die "unknown target '$mode' (expected 'all', 'latest' or tag(s) like v1.0.0)"
    ;;
esac

count=$(jq 'length' <<<"$selected")
if ((count > MAX_PACKAGES)); then
  echo "warning: ${count} releases selected; limiting to the oldest ${MAX_PACKAGES}" >&2
  selected=$(jq -c --argjson max "$MAX_PACKAGES" '.[-$max:] | reverse' <<<"$selected")
fi

jq . <<<"$selected"

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  {
    echo "matrix=$(jq -c <<<"$selected")"
    if [[ $(jq 'length' <<<"$selected") -gt 0 ]]; then
      echo "has_work=true"
    else
      echo "has_work=false"
    fi
  } >>"$GITHUB_OUTPUT"
fi
