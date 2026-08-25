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
# Architecture is selected with WEBVIEW_CEF_MACOS_ARCH:
#   host (default)  the build host's architecture
#   arm64           Apple Silicon only
#   x86_64          Intel only
#   universal       both, merged with lipo (needs ~8 GB of scratch space)
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

# --- resolve requested architecture(s) --------------------------------------
case "$(uname -m)" in
  arm64)  HOST_ARCH=arm64 ;;
  x86_64) HOST_ARCH=x86_64 ;;
  *)      err "unsupported host arch: $(uname -m)" ;;
esac

# The tag is part of the stamp file, so switching architectures re-prepares
# third/cef instead of silently reusing the wrong slices.
arch_tag() {
  case "$1" in
    arm64)  echo macosarm64 ;;
    x86_64) echo macosx64 ;;
  esac
}

REQUESTED="${WEBVIEW_CEF_MACOS_ARCH:-host}"
[ "${REQUESTED}" = host ] && REQUESTED="${HOST_ARCH}"
case "${REQUESTED}" in
  arm64|x86_64) ARCHS=("${REQUESTED}"); ARCH_TAG="$(arch_tag "${REQUESTED}")" ;;
  universal)    ARCHS=(arm64 x86_64);   ARCH_TAG="universal" ;;
  *) err "WEBVIEW_CEF_MACOS_ARCH must be host, arm64, x86_64 or universal (got '${REQUESTED}')" ;;
esac

cef_package() {
  case "$1" in
    arm64)  echo "cef_binary_${CEF_VERSION}_macosarm64" ;;
    x86_64) echo "cef_binary_${CEF_VERSION}_macosx64" ;;
  esac
}

# Fail early if a build artifact does not contain every architecture it should.
# Guards the lipo merge below: a missing slice only shows up as a link error in
# the host app (or a helper that cannot launch), far from its cause.
verify_archs() {
  local path="$1" have missing=()
  have="$(lipo -archs "${path}" 2>/dev/null)" || err "cannot read architectures of ${path}"
  for want in "${ARCHS[@]}"; do
    case " ${have} " in
      *" ${want} "*) ;;
      *) missing+=("${want}") ;;
    esac
  done
  [ ${#missing[@]} -eq 0 ] || err "${path} is missing the ${missing[*]} slice(s) (has: ${have})"
}

STAMP="${DEST}/version.txt"
WANT="${CEF_VERSION}_${ARCH_TAG}_${BUILD_TYPE}"

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

# --- fetch and build one distribution per requested architecture -------------
for arch in "${ARCHS[@]}"; do
  pkg="$(cef_package "${arch}")"
  tarball="${WORK}/${pkg}.tar.bz2"
  # CDN requires '+' percent-encoded as %2B.
  url="${CDN}/$(printf '%s' "${pkg}.tar.bz2" | sed 's/+/%2B/g')"

  echo "==> Downloading ${pkg}.tar.bz2"
  curl -L --fail --connect-timeout 30 -o "${tarball}" "${url}"

  echo "==> Extracting ${arch}"
  tar -xjf "${tarball}" -C "${WORK}"
  rm -f "${tarball}"
  [ -d "${WORK}/${pkg}" ] || err "extracted dir ${WORK}/${pkg} not found"

  echo "==> Building libcef_dll_wrapper (${BUILD_TYPE}, ${arch})"
  cmake -S "${WORK}/${pkg}" -B "${WORK}/${pkg}/build" -G "${GENERATOR}" \
    -DPROJECT_ARCH="${arch}" -DCMAKE_OSX_ARCHITECTURES="${arch}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 >/dev/null
  ( cd "${WORK}/${pkg}/build" && "${BUILD_TOOL[@]}" >/dev/null )
  [ -f "${WORK}/${pkg}/build/libcef_dll_wrapper/libcef_dll_wrapper.a" ] \
    || err "libcef_dll_wrapper.a was not produced for ${arch}"
done

PRIMARY="${WORK}/$(cef_package "${ARCHS[0]}")"

echo "==> Installing into ${DEST}"
rm -rf "${DEST}/include" "${DEST}/Chromium Embedded Framework.framework" \
       "${DEST}/libcef_dll_wrapper.a" "${DEST}/cef_helper" "${STAMP}"
mkdir -p "${DEST}"
# Headers are identical across the per-arch distributions.
cp -R "${PRIMARY}/include" "${DEST}/include"

# Merge (or copy) the wrapper. lipo on a single input is a plain copy, so the
# universal and single-arch paths stay the same code.
wrappers=()
for arch in "${ARCHS[@]}"; do
  wrappers+=("${WORK}/$(cef_package "${arch}")/build/libcef_dll_wrapper/libcef_dll_wrapper.a")
done
lipo -create "${wrappers[@]}" -output "${DEST}/libcef_dll_wrapper.a"
verify_archs "${DEST}/libcef_dll_wrapper.a"

# Lay the framework out as a versioned macOS bundle (Xcode embed/sign requires
# Versions/Current/Resources/Info.plist; CEF ships a flat bundle). Most Resources
# (locales, .pak/.dat blobs) are architecture independent, so they are taken from
# the primary distribution; the Mach-O parts and the V8 snapshot are merged.
FW_SRC="${PRIMARY}/Release/Chromium Embedded Framework.framework"
FW_DST="${DEST}/Chromium Embedded Framework.framework"
mkdir -p "${FW_DST}/Versions/A"
cp -R "${FW_SRC}/Chromium Embedded Framework" "${FW_DST}/Versions/A/"
cp -R "${FW_SRC}/Libraries" "${FW_DST}/Versions/A/"
cp -R "${FW_SRC}/Resources" "${FW_DST}/Versions/A/"
ln -sfn A "${FW_DST}/Versions/Current"
ln -sfn "Versions/Current/Chromium Embedded Framework" "${FW_DST}/Chromium Embedded Framework"
ln -sfn Versions/Current/Libraries "${FW_DST}/Libraries"
ln -sfn Versions/Current/Resources "${FW_DST}/Resources"

# The V8 startup snapshot is the one architecture-dependent resource. Chromium
# names it per architecture (v8_context_snapshot.<arch>.bin) precisely so a
# universal bundle can carry both and pick the right one at runtime, so each
# distribution's snapshot has to be copied in — the Resources above only carry
# the primary architecture's.
for arch in "${ARCHS[@]}"; do
  snapshot="v8_context_snapshot.${arch}.bin"
  snapshot_src="${WORK}/$(cef_package "${arch}")/Release/Chromium Embedded Framework.framework/Resources/${snapshot}"
  [ -f "${snapshot_src}" ] || err "${snapshot} not found in the ${arch} distribution"
  cp "${snapshot_src}" "${FW_DST}/Versions/A/Resources/${snapshot}"
done

if [ "${#ARCHS[@]}" -gt 1 ]; then
  echo "==> Merging framework binaries (${ARCHS[*]})"
  # The framework binary plus the ANGLE/SwiftShader dylibs next to it are the
  # only Mach-O files in the bundle. Each slice keeps its own code signature,
  # so the merged files stay loadable without re-signing.
  merge_into_framework() {
    local rel="$1" inputs=()
    for arch in "${ARCHS[@]}"; do
      inputs+=("${WORK}/$(cef_package "${arch}")/Release/Chromium Embedded Framework.framework/${rel}")
    done
    lipo -create "${inputs[@]}" -output "${FW_DST}/Versions/A/${rel}"
    verify_archs "${FW_DST}/Versions/A/${rel}"
  }
  merge_into_framework "Chromium Embedded Framework"
  for lib in "${FW_SRC}/Libraries/"*.dylib; do
    merge_into_framework "Libraries/$(basename "${lib}")"
  done
fi
verify_archs "${FW_DST}/Versions/A/Chromium Embedded Framework"

# Build the standalone CEF helper executable used by the multi-process helper
# bundles (embed_cef_helpers.sh clones this into the 5 named .app bundles).
# It links the wrapper statically; the framework is dlopen'd at runtime
# (LoadInHelper), so it does not link the framework here.
echo "==> Building CEF helper executable (${ARCHS[*]})"
arch_flags=()
for arch in "${ARCHS[@]}"; do
  arch_flags+=(-arch "${arch}")
done
clang++ -std=c++20 -stdlib=libc++ -mmacosx-version-min=12.0 -w \
  "${arch_flags[@]}" \
  -I "${DEST}" -I "${REPO_ROOT}/common" \
  "${MACOS_DIR}/helper/cef_helper_main.mm" \
  "${DEST}/libcef_dll_wrapper.a" \
  -framework Foundation -framework AppKit \
  -Wl,-ObjC \
  -o "${DEST}/cef_helper"
[ -f "${DEST}/cef_helper" ] || err "cef_helper was not produced"
verify_archs "${DEST}/cef_helper"

echo "${WANT}" > "${STAMP}"
echo "==> Done: CEF ${CEF_VERSION} (${ARCH_TAG}, wrapper ${BUILD_TYPE}) ready in ${DEST}"
