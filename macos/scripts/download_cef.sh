#!/usr/bin/env bash
#
# Downloads and installs the prebuilt CEF (Chromium Embedded Framework) binaries
# for macOS into macos/third/cef so that `pod install` / the build can link them.
#
# This is invoked automatically from webview_cef.podspec, but can also be run by
# hand. It mirrors the auto-download approach Windows already uses in
# windows/cmake/Downloader.cmake.
#
# Architecture selection (highest priority first):
#   1. WEBVIEW_CEF_MACOS_ARCH env var: "arm64" | "intel" | "universal"
#   2. host architecture via `uname -m` (arm64 -> arm64, x86_64 -> intel)
#
# Examples:
#   bash macos/scripts/download_cef.sh
#   WEBVIEW_CEF_MACOS_ARCH=universal bash macos/scripts/download_cef.sh
#
set -euo pipefail

# --- Configuration ----------------------------------------------------------

CEF_VERSION="103.0.12"

ARM64_URL="https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac_arm64/CEFbins-mac103.0.12-arm64.zip"
INTEL_URL="https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac_intel/mac103.0.12-Intel.zip"
UNIVERSAL_URL="https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac_universal/mac103.0.12-universal.zip"

FRAMEWORK_NAME="Chromium Embedded Framework.framework"
WRAPPER_NAME="libcef_dll_wrapper.a"

# --- Paths ------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/third/cef"
MARKER_FILE="${THIRD_DIR}/.cef_version"

# --- Helpers ----------------------------------------------------------------

log()  { printf '[webview_cef] %s\n' "$*"; }
fail() {
  printf '[webview_cef] ERROR: %s\n' "$*" >&2
  printf '[webview_cef] Falling back is possible: download the CEF zip manually and\n' >&2
  printf '[webview_cef] unzip its contents into:\n  %s\n' "${THIRD_DIR}" >&2
  printf '[webview_cef] See the macOS setup section of the README for the links.\n' >&2
  exit 1
}

# --- Resolve target architecture -------------------------------------------

ARCH="${WEBVIEW_CEF_MACOS_ARCH:-}"
if [ -z "${ARCH}" ]; then
  case "$(uname -m)" in
    arm64)  ARCH="arm64" ;;
    x86_64) ARCH="intel" ;;
    *)      fail "Unsupported host architecture '$(uname -m)'. Set WEBVIEW_CEF_MACOS_ARCH to arm64, intel, or universal." ;;
  esac
fi

case "${ARCH}" in
  arm64)     URL="${ARM64_URL}" ;;
  intel)     URL="${INTEL_URL}" ;;
  universal) URL="${UNIVERSAL_URL}" ;;
  *)         fail "Invalid WEBVIEW_CEF_MACOS_ARCH='${ARCH}'. Expected arm64, intel, or universal." ;;
esac

EXPECTED_MARKER="${CEF_VERSION}-${ARCH}"

# --- Skip if already installed and matching --------------------------------

if [ -d "${THIRD_DIR}/${FRAMEWORK_NAME}" ] && \
   [ -f "${THIRD_DIR}/${WRAPPER_NAME}" ] && \
   [ -f "${MARKER_FILE}" ] && \
   [ "$(cat "${MARKER_FILE}" 2>/dev/null)" = "${EXPECTED_MARKER}" ]; then
  log "CEF ${EXPECTED_MARKER} already installed in third/cef — skipping download."
  exit 0
fi

command -v curl  >/dev/null 2>&1 || fail "'curl' is required but was not found."
command -v unzip >/dev/null 2>&1 || fail "'unzip' is required but was not found."

# --- Download & extract -----------------------------------------------------

mkdir -p "${THIRD_DIR}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/webview_cef_cef.XXXXXX")"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

ZIP_PATH="${TMP_DIR}/cef.zip"

log "Downloading CEF ${CEF_VERSION} (${ARCH}) ..."
log "  ${URL}"
curl -L --fail --progress-bar -o "${ZIP_PATH}" "${URL}" \
  || fail "Download failed from ${URL}"

log "Extracting ..."
unzip -q "${ZIP_PATH}" -d "${TMP_DIR}/extracted" \
  || fail "Failed to unzip ${ZIP_PATH}"

# These zips are created on macOS and carry a parallel __MACOSX/ tree of
# AppleDouble (._*) resource-fork files, including a shadow copy of the
# .framework directory. Remove it so the artifact search below cannot match the
# hollow shadow instead of the real framework.
find "${TMP_DIR}/extracted" -type d -name "__MACOSX" -prune -exec rm -rf {} + 2>/dev/null || true

# The three release zips differ in internal nesting, so locate each artifact
# wherever it landed in the extracted tree instead of assuming a fixed layout.
SRC_FRAMEWORK="$(find "${TMP_DIR}/extracted" -path '*__MACOSX*' -prune -o -type d -name "${FRAMEWORK_NAME}" -print -quit || true)"
SRC_WRAPPER="$(find "${TMP_DIR}/extracted" -path '*__MACOSX*' -prune -o -type f -name "${WRAPPER_NAME}" -print -quit || true)"
SRC_INCLUDE="$(find "${TMP_DIR}/extracted" -path '*__MACOSX*' -prune -o -type d -name "include" -print -quit || true)"

[ -n "${SRC_FRAMEWORK}" ] || fail "Could not find '${FRAMEWORK_NAME}' inside the downloaded archive."
[ -n "${SRC_WRAPPER}" ]   || fail "Could not find '${WRAPPER_NAME}' inside the downloaded archive."

# Install framework (replace any existing copy).
log "Installing ${FRAMEWORK_NAME} ..."
rm -rf "${THIRD_DIR:?}/${FRAMEWORK_NAME}"
mv "${SRC_FRAMEWORK}" "${THIRD_DIR}/${FRAMEWORK_NAME}"

# Install wrapper static library.
log "Installing ${WRAPPER_NAME} ..."
rm -f "${THIRD_DIR}/${WRAPPER_NAME}"
mv "${SRC_WRAPPER}" "${THIRD_DIR}/${WRAPPER_NAME}"

# Headers are committed to the repo, so only install them when missing (e.g. a
# CEF version bump or a partial checkout). Avoids needlessly churning tracked files.
if [ -n "${SRC_INCLUDE}" ] && [ ! -d "${THIRD_DIR}/include" ]; then
  log "Installing CEF headers (include/) ..."
  mv "${SRC_INCLUDE}" "${THIRD_DIR}/include"
fi

# Sanity-check the install: a hollow .framework (no Mach-O binary) links fine at
# pod install time but fails the app at runtime, so verify the binary is present.
FRAMEWORK_BINARY="${THIRD_DIR}/${FRAMEWORK_NAME}/Chromium Embedded Framework"
[ -f "${FRAMEWORK_BINARY}" ] || fail "Installed framework is missing its Mach-O binary at '${FRAMEWORK_BINARY}'. The archive layout may have changed."

printf '%s' "${EXPECTED_MARKER}" > "${MARKER_FILE}"

log "Done. CEF ${EXPECTED_MARKER} installed into third/cef."
