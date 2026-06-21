#!/usr/bin/env bash
#
# Download the official CEF "Standard Distribution" for macOS and prepare
# macos/third/cef for the CocoaPods build. This is the macOS counterpart of
# the CMake `prepare_prebuilt_files` path used on Windows/Linux
# (see third/download.cmake): nothing under macos/third/cef is tracked in git;
# it is fetched/built on demand.
#
# It performs three steps that previously had to be done by hand (see README):
#   1. download + extract the CEF distribution (provides include/ headers)
#   2. lay the framework out as a versioned macOS bundle (Versions/A + symlinks)
#   3. build libcef_dll_wrapper.a from the distribution's sources
#
# The CEF version is read from third/download.cmake so there is a single source
# of truth shared with Windows/Linux. Re-running is cheap: if the destination is
# already populated for the pinned version it exits immediately.
#
# Override the wrapper build type with CEF_WRAPPER_BUILD_TYPE=Release (defaults
# to Debug to match `flutter run` / `flutter build macos --debug`).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"          # .../macos
REPO_ROOT="$(cd "${MACOS_DIR}/.." && pwd)"           # repo root
DEST="${MACOS_DIR}/third/cef"                        # where the podspec looks
DOWNLOAD_CMAKE="${REPO_ROOT}/third/download.cmake"
BUILD_TYPE="${CEF_WRAPPER_BUILD_TYPE:-Debug}"
CDN="https://cef-builds.spotifycdn.com"

err() { echo "error: $*" >&2; exit 1; }

# --- resolve version (single source of truth: third/download.cmake) ----------
[ -f "${DOWNLOAD_CMAKE}" ] || err "cannot find ${DOWNLOAD_CMAKE}"
CEF_VERSION="$(sed -n 's/^[[:space:]]*set(CEF_VERSION[[:space:]]*"\(.*\)").*/\1/p' "${DOWNLOAD_CMAKE}" | head -1)"
[ -n "${CEF_VERSION}" ] || err "could not parse CEF_VERSION from ${DOWNLOAD_CMAKE}"

case "$(uname -m)" in
  arm64)  CEF_ARCH="macosarm64"; PROJECT_ARCH="arm64" ;;
  x86_64) CEF_ARCH="macosx64";   PROJECT_ARCH="x86_64" ;;
  *)      err "unsupported arch: $(uname -m)" ;;
esac

PKG="cef_binary_${CEF_VERSION}_${CEF_ARCH}"
STAMP="${DEST}/version.txt"
WANT="${CEF_VERSION}_${CEF_ARCH}_${BUILD_TYPE}"

# --- skip if already prepared for this exact version/arch/type ---------------
if [ -f "${STAMP}" ] && [ "$(cat "${STAMP}" 2>/dev/null)" = "${WANT}" ] \
   && [ -f "${DEST}/libcef_dll_wrapper.a" ] \
   && [ -f "${DEST}/cef_helper" ] \
   && [ -e "${DEST}/Chromium Embedded Framework.framework/Resources/Info.plist" ] \
   && [ -f "${DEST}/include/cef_version.h" ]; then
  echo "CEF ${WANT} already prepared in ${DEST} — nothing to do."
  exit 0
fi

command -v cmake >/dev/null || err "cmake not found (brew install cmake) — needed to build libcef_dll_wrapper"
if command -v ninja >/dev/null && ninja --version >/dev/null 2>&1; then
  GENERATOR="Ninja"; BUILD_TOOL=(ninja libcef_dll_wrapper)
else
  GENERATOR="Unix Makefiles"; BUILD_TOOL=(make -j"$(sysctl -n hw.ncpu)" libcef_dll_wrapper)
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cef_dl.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
TARBALL="${WORK}/${PKG}.tar.bz2"
# CDN requires '+' percent-encoded as %2B.
URL="${CDN}/$(printf '%s' "${PKG}.tar.bz2" | sed 's/+/%2B/g')"

echo "==> Downloading ${PKG}.tar.bz2"
curl -L --fail --connect-timeout 30 -o "${TARBALL}" "${URL}"

echo "==> Extracting"
tar -xjf "${TARBALL}" -C "${WORK}"
SRC="${WORK}/${PKG}"
[ -d "${SRC}" ] || err "extracted dir ${SRC} not found"

echo "==> Building libcef_dll_wrapper (${BUILD_TYPE}, ${PROJECT_ARCH})"
cmake -S "${SRC}" -B "${SRC}/build" -G "${GENERATOR}" \
  -DPROJECT_ARCH="${PROJECT_ARCH}" -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 >/dev/null
( cd "${SRC}/build" && "${BUILD_TOOL[@]}" >/dev/null )
WRAPPER="${SRC}/build/libcef_dll_wrapper/libcef_dll_wrapper.a"
[ -f "${WRAPPER}" ] || err "libcef_dll_wrapper.a was not produced"

echo "==> Installing into ${DEST}"
rm -rf "${DEST}/include" "${DEST}/Chromium Embedded Framework.framework" \
       "${DEST}/libcef_dll_wrapper.a" "${STAMP}"
mkdir -p "${DEST}"
cp -R "${SRC}/include" "${DEST}/include"
cp "${WRAPPER}" "${DEST}/libcef_dll_wrapper.a"

# Lay the framework out as a versioned macOS bundle (Xcode embed/sign requires
# Versions/Current/Resources/Info.plist; CEF ships a flat bundle).
FW_SRC="${SRC}/Release/Chromium Embedded Framework.framework"
FW_DST="${DEST}/Chromium Embedded Framework.framework"
mkdir -p "${FW_DST}/Versions/A"
cp -R "${FW_SRC}/Chromium Embedded Framework" "${FW_DST}/Versions/A/"
cp -R "${FW_SRC}/Libraries" "${FW_DST}/Versions/A/"
cp -R "${FW_SRC}/Resources" "${FW_DST}/Versions/A/"
ln -sfn A "${FW_DST}/Versions/Current"
ln -sfn "Versions/Current/Chromium Embedded Framework" "${FW_DST}/Chromium Embedded Framework"
ln -sfn Versions/Current/Libraries "${FW_DST}/Libraries"
ln -sfn Versions/Current/Resources "${FW_DST}/Resources"

# Build the standalone CEF helper executable used by the multi-process helper
# bundles (embed_cef_helpers.sh clones this into the 5 named .app bundles).
# It links the wrapper statically; the framework is dlopen'd at runtime
# (LoadInHelper), so it does not link the framework here.
echo "==> Building CEF helper executable"
clang++ -std=c++20 -stdlib=libc++ -mmacosx-version-min=12.0 -w \
  -I "${DEST}" -I "${REPO_ROOT}/common" \
  "${MACOS_DIR}/helper/cef_helper_main.mm" \
  "${DEST}/libcef_dll_wrapper.a" \
  -framework Foundation -framework AppKit \
  -Wl,-ObjC \
  -o "${DEST}/cef_helper"
[ -f "${DEST}/cef_helper" ] || err "cef_helper was not produced"

echo "${WANT}" > "${STAMP}"
echo "==> Done: CEF ${CEF_VERSION} (${CEF_ARCH}, wrapper ${BUILD_TYPE}) ready in ${DEST}"
