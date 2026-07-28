#!/usr/bin/env bash
#
# Download CEF "Standard Distribution" tarballs into cef_tar/ for offline builds.
#
# By default pod install downloads CEF from Spotify CDN, which can be very slow
# on some networks. Pre-downloading the tarballs with this script and placing
# them in cef_tar/ lets download_cef.sh skip the CDN step entirely.
#
# Usage:
#   bash cef_tar/download_cef_tars.sh          # download both architectures
#
# The CEF version is read from third/download.cmake (single source of truth).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DOWNLOAD_CMAKE="${REPO_ROOT}/third/download.cmake"
[ -f "${DOWNLOAD_CMAKE}" ] || { echo "error: cannot find ${DOWNLOAD_CMAKE}" >&2; exit 1; }

CEF_VERSION="$(sed -n 's/^[[:space:]]*set(CEF_VERSION[[:space:]]*"\(.*\)").*/\1/p' "${DOWNLOAD_CMAKE}" | head -1)"
[ -n "${CEF_VERSION}" ] || { echo "error: could not parse CEF_VERSION from ${DOWNLOAD_CMAKE}" >&2; exit 1; }

CDN="https://cef-builds.spotifycdn.com"
ARCHES=("arm64:macosarm64" "x86_64:macosx64")

echo "CEF version: ${CEF_VERSION}"
echo "Target dir:  ${SCRIPT_DIR}"
echo ""

for entry in "${ARCHES[@]}"; do
  arch="${entry%%:*}"
  cef_arch="${entry##*:}"
  pkg="cef_binary_${CEF_VERSION}_${cef_arch}"
  tarball="${SCRIPT_DIR}/${pkg}.tar.bz2"
  url="${CDN}/$(printf '%s' "${pkg}.tar.bz2" | sed 's/+/%2B/g')"

  if [ -f "${tarball}" ]; then
    echo "==> ${pkg}.tar.bz2 already exists, skipping."
    continue
  fi

  echo "==> Downloading ${pkg}.tar.bz2 (${arch})..."
  curl -L --fail --connect-timeout 30 --max-time 3600 \
       --retry 3 --retry-delay 5 \
       -C - -o "${tarball}" "${url}"
  echo "    Done."
done

echo ""
echo "All tarballs ready. pod install will now use them directly."
