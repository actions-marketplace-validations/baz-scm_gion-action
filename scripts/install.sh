#!/usr/bin/env bash
# Installs a gion release into the runner's tool cache and puts it on PATH.
#
# Environment:
#   GION_VERSION  release to install, e.g. v0.3.1 (default: latest)
set -euo pipefail

repo=baz-scm/gion
fail() { echo "::error::gion setup: $*" >&2; exit 1; }

case "${RUNNER_OS:-$(uname -s)}" in
  Linux) os=linux ;;
  macOS | Darwin) os=darwin ;;
  *) fail "unsupported runner OS ${RUNNER_OS:-$(uname -s)}; gion ships Linux and macOS builds" ;;
esac
case "${RUNNER_ARCH:-$(uname -m)}" in
  X64 | x86_64 | amd64) arch=amd64 ;;
  ARM64 | aarch64 | arm64) arch=arm64 ;;
  *) fail "unsupported runner arch ${RUNNER_ARCH:-$(uname -m)}" ;;
esac

version=${GION_VERSION:-latest}
if [[ $version == latest ]]; then
  # The latest-release page redirects to .../tag/<version>; no API token or
  # rate limit involved.
  url=$(curl -fsSLI --retry 3 -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest") ||
    fail "couldn't reach github.com"
  version=${url##*/}
fi
[[ $version == v* ]] || version=v$version

# The tool cache survives between jobs on self-hosted runners, so a version
# is downloaded once per machine there.
dir=${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:-/tmp}}/gion/${version#v}/$arch
if [[ ! -x $dir/gion ]]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  archive="gion_${version#v}_${os}_${arch}.tar.gz"
  base="https://github.com/$repo/releases/download/$version"
  curl -fsSL --retry 3 -o "$tmp/$archive" "$base/$archive" ||
    fail "couldn't download $archive; is $version a gion release?"
  curl -fsSL --retry 3 -o "$tmp/checksums.txt" "$base/checksums.txt" ||
    fail "couldn't download checksums.txt for $version"

  want=$(awk -v f="$archive" '$2 == f { print $1 }' "$tmp/checksums.txt")
  [[ -n $want ]] || fail "$archive is not in checksums.txt"
  if command -v sha256sum >/dev/null; then
    got=$(sha256sum "$tmp/$archive" | awk '{ print $1 }')
  else
    got=$(shasum -a 256 "$tmp/$archive" | awk '{ print $1 }')
  fi
  [[ $got == "$want" ]] || fail "checksum mismatch for $archive"

  mkdir -p "$dir"
  tar -xzf "$tmp/$archive" -C "$dir" gion
fi

"$dir/gion" version
echo "$dir" >>"$GITHUB_PATH"
{
  echo "version=$version"
  echo "path=$dir/gion"
} >>"$GITHUB_OUTPUT"
