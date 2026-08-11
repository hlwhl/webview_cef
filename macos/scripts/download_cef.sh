#!/usr/bin/env bash
#
# Download the official CEF "Standard Distribution" for macOS and prepare
# macos/third/cef for the CocoaPods build. This is the macOS counterpart of
# the CMake `prepare_prebuilt_files` path used on Windows/Linux
# (see third/download.cmake): nothing under macos/third/cef is tracked in git;
# it is fetched/built on demand.
#
# By default this script produces a universal (arm64 + x86_64) CEF:
# both architecture packages are downloaded, built separately, and merged with
# lipo. Set CEF_UNIVERSAL=0 to fall back to a single host-architecture build
# (emergency escape hatch for low-disk / poor-network situations).
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

# --- helpers ------------------------------------------------------------------
cef_arch_for() {
  case "$1" in
    arm64)  echo "macosarm64" ;;
    x86_64) echo "macosx64" ;;
  esac
}

# --- determine target architectures -------------------------------------------
# Default: universal (arm64 + x86_64). Set CEF_UNIVERSAL=0 for single-arch
# fallback (emergency escape hatch).
if [ "${CEF_UNIVERSAL:-}" = "0" ]; then
  case "$(uname -m)" in
    arm64)  ARCHES=("arm64") ;;
    x86_64) ARCHES=("x86_64") ;;
    *)      err "unsupported arch: $(uname -m)" ;;
  esac
else
  ARCHES=("arm64" "x86_64")
fi

# Build human-readable arch label for the stamp.
if [ ${#ARCHES[@]} -gt 1 ]; then
  ARCH_LABEL="arm64,x86_64"
else
  ARCH_LABEL="$(cef_arch_for "${ARCHES[0]}")"
fi

STAMP="${DEST}/version.txt"
WANT="${CEF_VERSION}_${ARCH_LABEL}_${BUILD_TYPE}"

# --- compute source-content hash for the helper's dependencies ----------------
# When any source file compiled into cef_helper changes, the hash embedded in
# the stamp won't match and the helper (together with the wrapper) is rebuilt on
# the next pod install. This prevents stale renderer-process binaries that would
# still run old V8 extension code (e.g. the retired |external| namespace) after
# devs edit common/*.cc.
HELPER_SOURCES=(
  "${MACOS_DIR}/helper/cef_helper_main.mm"
  "${REPO_ROOT}/common/webview_app.h"
  "${REPO_ROOT}/common/webview_app.cc"
  "${REPO_ROOT}/common/webview_handler.h"
  "${REPO_ROOT}/common/webview_handler.cc"
  "${REPO_ROOT}/common/webview_cookieVisitor.h"
  "${REPO_ROOT}/common/webview_cookieVisitor.cc"
  "${REPO_ROOT}/common/webview_js_handler.h"
  "${REPO_ROOT}/common/webview_js_handler.cc"
  "${REPO_ROOT}/common/webview_plugin.h"
  "${REPO_ROOT}/common/webview_plugin.cc"
  "${REPO_ROOT}/common/webview_value.h"
  "${REPO_ROOT}/common/webview_value.cc"
)
SOURCE_HASH=$(cat "${HELPER_SOURCES[@]}" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
WANT="${WANT}_${SOURCE_HASH}"

# --- helpers ------------------------------------------------------------------
is_fat() {
  lipo -info "$1" 2>/dev/null | grep -q 'Architectures in the fat file'
}

# --- skip if already prepared for this exact version / arch / type -----------
cache_valid() {
  [ -f "${STAMP}" ] || return 1
  [ "$(cat "${STAMP}" 2>/dev/null)" = "${WANT}" ] || return 1
  [ -f "${DEST}/include/cef_version.h" ] || return 1

  if [ ${#ARCHES[@]} -gt 1 ]; then
    # Universal: additionally verify key files are actually fat.
    is_fat "${DEST}/libcef_dll_wrapper.a" || return 1
    is_fat "${DEST}/cef_helper" || return 1
    is_fat "${DEST}/Chromium Embedded Framework.framework/Versions/A/Chromium Embedded Framework" || return 1
  else
    [ -f "${DEST}/libcef_dll_wrapper.a" ] || return 1
    [ -f "${DEST}/cef_helper" ] || return 1
    [ -e "${DEST}/Chromium Embedded Framework.framework/Resources/Info.plist" ] || return 1
  fi
  return 0
}

if cache_valid; then
  echo "==> CEF ${CEF_VERSION} (${ARCH_LABEL}, ${BUILD_TYPE}) already prepared — nothing to do."
  exit 0
fi

echo "==> Preparing CEF ${CEF_VERSION} (${ARCH_LABEL}, ${BUILD_TYPE})"

# --- tool checks -------------------------------------------------------------
command -v cmake >/dev/null || err "cmake not found (brew install cmake) — needed to build libcef_dll_wrapper"
if command -v ninja >/dev/null && ninja --version >/dev/null 2>&1; then
  GENERATOR="Ninja"; BUILD_TOOL=(ninja libcef_dll_wrapper)
else
  GENERATOR="Unix Makefiles"; BUILD_TOOL=(make -j"$(sysctl -n hw.ncpu)" libcef_dll_wrapper)
fi

if [ ${#ARCHES[@]} -gt 1 ]; then
  command -v lipo >/dev/null || err "lipo not found — required for universal binary merge"
fi

# --- temporary build directories ----------------------------------------------
TEMP_DIRS=()
for arch in "${ARCHES[@]}"; do
  TEMP_DIR="${DEST}/_build_${arch}"
  rm -rf "${TEMP_DIR}"
  mkdir -p "${TEMP_DIR}"
  TEMP_DIRS+=("${TEMP_DIR}")
done

cleanup() {
  for d in "${TEMP_DIRS[@]}"; do
    rm -rf "${d}"
  done
}
trap cleanup EXIT

# --- download_and_build(arch, cef_arch, work_dir) ----------------------------
# Downloads the CEF package for a single architecture, extracts it, builds
# libcef_dll_wrapper.a and cef_helper. The helper must be built per-architecture
# (arm64 helper links arm64 wrapper, x86_64 helper links x86_64 wrapper);
# lipo merges them afterwards.
download_and_build() {
  local arch=$1
  local cef_arch=$2
  local work=$3

  local pkg="cef_binary_${CEF_VERSION}_${cef_arch}"
  local tarball="${work}/${pkg}.tar.bz2"

  # If a local tarball exists under cef_tar/ (committed to the repo for
  # offline builds), use it directly — saves ~10 minutes of slow CDN download.
  local local_tar="${REPO_ROOT}/cef_tar/${pkg}.tar.bz2"
  if [ -f "${local_tar}" ]; then
    echo "==> Using local ${pkg}.tar.bz2 (${arch}) from cef_tar/"
    cp "${local_tar}" "${tarball}"
  else
    # CDN requires '+' percent-encoded as %2B.
    local url="${CDN}/$(printf '%s' "${pkg}.tar.bz2" | sed 's/+/%2B/g')"

    echo "==> Downloading ${pkg}.tar.bz2 (${arch})"
    # curl --retry does NOT cover error 18 (partial transfer) by default,
    # so we implement a bash-level retry loop with resume (-C -) support.
    # The server supports Range requests, so each attempt appends to the partial
    # file. This is critical when the CDN connection is unstable: even if every
    # attempt delivers only a few MB before being cut off, enough attempts will
    # eventually complete the download.
    local max_attempts=3
    local retry_delay_sec=5
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
      if [ -f "${tarball}" ]; then
        local downloaded
        downloaded=$(stat -f%z "${tarball}" 2>/dev/null || echo 0)
        echo "  [${attempt}/${max_attempts}] Resuming from ${downloaded} bytes"
      else
        echo "  [${attempt}/${max_attempts}] Starting download..."
      fi
      if curl -L --fail --connect-timeout 30 --max-time 1800 \
           --retry-all-errors --retry 3 --retry-delay 5 \
           -C - -o "${tarball}" "${url}"; then
        echo "==> Download complete (${arch})"
        break
      fi
      local rc=$?
      echo "  curl exited with code ${rc}"
      if [ $attempt -ge $max_attempts ]; then
        err "Download failed after ${max_attempts} attempts (${arch})"
      fi
      sleep $retry_delay_sec
      attempt=$((attempt + 1))
    done
  fi

  echo "==> Extracting (${arch})"
  if ! tar -xjf "${tarball}" -C "${work}"; then
    err "Extraction failed (${arch}) — the downloaded archive may be corrupted. Try removing any cached partial download and re-run."
  fi
  local src="${work}/${pkg}"
  [ -d "${src}" ] || err "extracted dir ${src} not found (${arch})"

  echo "==> Building libcef_dll_wrapper (${BUILD_TYPE}, ${arch})"
  cmake -S "${src}" -B "${src}/build" -G "${GENERATOR}" \
    -DPROJECT_ARCH="${arch}" -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 >/dev/null 2>&1
  echo "    cmake configured (${arch})"
  ( cd "${src}/build" && "${BUILD_TOOL[@]}" >/dev/null 2>&1 )
  echo "    libcef_dll_wrapper built (${arch})"
  local wrapper="${src}/build/libcef_dll_wrapper/libcef_dll_wrapper.a"
  [ -f "${wrapper}" ] || err "libcef_dll_wrapper.a was not produced (${arch})"

  echo "==> Building cef_helper (${arch})"
  clang++ -std=c++20 -stdlib=libc++ -mmacosx-version-min=12.0 -w \
    -arch "${arch}" \
    -I "${src}" -I "${REPO_ROOT}/common" \
    "${MACOS_DIR}/helper/cef_helper_main.mm" \
    "${wrapper}" \
    -framework Foundation -framework AppKit \
    -Wl,-ObjC \
    -o "${work}/cef_helper"
  [ -f "${work}/cef_helper" ] || err "cef_helper was not produced (${arch})"
}

# --- execute per-architecture build (sequential) -----------------------------
  TOTAL=${#ARCHES[@]}
  for i in "${!ARCHES[@]}"; do
    arch="${ARCHES[$i]}"
    cef_arch="$(cef_arch_for "$arch")"
    step=$((i + 1))
    echo "==> [${step}/${TOTAL}] Building ${arch} (${cef_arch})"
    work="${TEMP_DIRS[$i]}"
    download_and_build "${arch}" "${cef_arch}" "${work}"
  done

# --- prepare destination -----------------------------------------------------
echo "==> Installing into ${DEST}"
rm -rf "${DEST}/include" "${DEST}/Chromium Embedded Framework.framework" \
       "${DEST}/libcef_dll_wrapper.a" "${DEST}/cef_helper" "${STAMP}"
mkdir -p "${DEST}"

# Convenience: extract the first (or only) arch's source directory.
FIRST_ARCH="${ARCHES[0]}"
FIRST_CEF_ARCH="$(cef_arch_for "$FIRST_ARCH")"
FIRST_SRC="${TEMP_DIRS[0]}/cef_binary_${CEF_VERSION}_${FIRST_CEF_ARCH}"

# Headers are identical across architectures — copy from the first package.
cp -R "${FIRST_SRC}/include" "${DEST}/include"
echo "  include headers installed"

if [ ${#ARCHES[@]} -gt 1 ]; then
  # =========================================================================
  # Universal path: lipo-merge everything.
  # =========================================================================

  SECOND_ARCH="${ARCHES[1]}"
  SECOND_CEF_ARCH="$(cef_arch_for "$SECOND_ARCH")"
  SECOND_SRC="${TEMP_DIRS[1]}/cef_binary_${CEF_VERSION}_${SECOND_CEF_ARCH}"

  # --- lipo libcef_dll_wrapper.a ------------------------------------------
  echo "==> Merging libcef_dll_wrapper.a (arm64 + x86_64 → universal)"
  ARM64_WRAPPER=$(find "${TEMP_DIRS[0]}" -name "libcef_dll_wrapper.a" -path "*/libcef_dll_wrapper/*" | head -1)
  X86_64_WRAPPER=$(find "${TEMP_DIRS[1]}" -name "libcef_dll_wrapper.a" -path "*/libcef_dll_wrapper/*" | head -1)
  lipo -create "${ARM64_WRAPPER}" "${X86_64_WRAPPER}" \
    -output "${DEST}/libcef_dll_wrapper.a"

  # --- install & lipo Chromium Embedded Framework.framework ---------------
  echo "==> Merging Chromium Embedded Framework.framework"
  FW_SRC_ARM64="${FIRST_SRC}/Release/Chromium Embedded Framework.framework"
  FW_SRC_X86_64="${SECOND_SRC}/Release/Chromium Embedded Framework.framework"

  # Lay the framework out as a versioned macOS bundle using arm64 as the base
  # (Xcode embed/sign requires Versions/Current/Resources/Info.plist; CEF
  # ships a flat bundle).
  FW_DST="${DEST}/Chromium Embedded Framework.framework"
  mkdir -p "${FW_DST}/Versions/A"
  cp -R "${FW_SRC_ARM64}/Chromium Embedded Framework" "${FW_DST}/Versions/A/"
  cp -R "${FW_SRC_ARM64}/Libraries" "${FW_DST}/Versions/A/"
  cp -R "${FW_SRC_ARM64}/Resources" "${FW_DST}/Versions/A/"
  ln -sfn A "${FW_DST}/Versions/Current"
  ln -sfn "Versions/Current/Chromium Embedded Framework" "${FW_DST}/Chromium Embedded Framework"
  ln -sfn Versions/Current/Libraries "${FW_DST}/Libraries"
  ln -sfn Versions/Current/Resources "${FW_DST}/Resources"

  # Scan every Mach-O file in the framework and lipo-merge with its x86_64
  # counterpart. This auto-adapts to CEF upgrades (new/removed dylibs).
  echo "  (scanning framework for Mach-O files...)"
  merged_count=0
  while IFS= read -r f; do
    if file "$f" 2>/dev/null | grep -q "Mach-O"; then
      rel="${f#$FW_DST}"
      # FW_DST uses a versioned layout (Versions/A/...), but the x86_64
      # source is a flat bundle. Strip the Versions/A/ prefix to map.
      flat_rel="${rel#/Versions/A/}"
      x86_file="${FW_SRC_X86_64}/${flat_rel}"

      if [ -f "$x86_file" ]; then
        echo "    lipo: ${rel}"
        lipo -create "$f" "$x86_file" -output "$f.tmp" || err "lipo failed for ${rel}"
        mv "$f.tmp" "$f"
        merged_count=$((merged_count + 1))
      fi
    fi
  done < <(find "${FW_DST}" -type f)
  echo "  ${merged_count} Mach-O file(s) merged"

  # --- lipo cef_helper ----------------------------------------------------
  echo "==> Merging cef_helper (arm64 + x86_64 → universal)"
  lipo -create "${TEMP_DIRS[0]}/cef_helper" "${TEMP_DIRS[1]}/cef_helper" \
    -output "${DEST}/cef_helper"
  [ -f "${DEST}/cef_helper" ] || err "cef_helper was not produced"

else
  # =========================================================================
  # Single-arch fallback path (CEF_UNIVERSAL=0): copy directly, no lipo.
  # =========================================================================

  cp "${FIRST_SRC}/build/libcef_dll_wrapper/libcef_dll_wrapper.a" "${DEST}/libcef_dll_wrapper.a"

  # Lay the framework out as a versioned macOS bundle.
  FW_SRC="${FIRST_SRC}/Release/Chromium Embedded Framework.framework"
  FW_DST="${DEST}/Chromium Embedded Framework.framework"
  mkdir -p "${FW_DST}/Versions/A"
  cp -R "${FW_SRC}/Chromium Embedded Framework" "${FW_DST}/Versions/A/"
  cp -R "${FW_SRC}/Libraries" "${FW_DST}/Versions/A/"
  cp -R "${FW_SRC}/Resources" "${FW_DST}/Versions/A/"
  ln -sfn A "${FW_DST}/Versions/Current"
  ln -sfn "Versions/Current/Chromium Embedded Framework" "${FW_DST}/Chromium Embedded Framework"
  ln -sfn Versions/Current/Libraries "${FW_DST}/Libraries"
  ln -sfn Versions/Current/Resources "${FW_DST}/Resources"

  cp "${TEMP_DIRS[0]}/cef_helper" "${DEST}/cef_helper"
fi

# --- write stamp (atomic: .tmp → rename) ------------------------------------
echo "${WANT}" > "${STAMP}.tmp" && mv "${STAMP}.tmp" "${STAMP}"
echo "==> Done: CEF ${CEF_VERSION} (${ARCH_LABEL}, wrapper ${BUILD_TYPE}) ready in ${DEST}"
