# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "webview_cef")
project(${PROJECT_NAME} LANGUAGES CXX)

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
message(STATUS "${CMAKE_BUILD_TYPE}")
endif()

# Download the official CEF "Standard Distribution" into ../third/cef. The
# wrapper (libcef_dll_wrapper) is built from source below, so there is no
# dependency on any custom-packaged prebuilt binaries.
include(${CMAKE_CURRENT_SOURCE_DIR}/../third/download.cmake)
prepare_prebuilt_files(${CMAKE_CURRENT_SOURCE_DIR}/../third/cef)

# Build the CEF C++ wrapper with the dynamic CRT (/MD) that Flutter uses, and
# without the CEF sandbox (the plugin initializes CEF with no_sandbox = true).
# These must be set before find_package(CEF).
set(USE_SANDBOX OFF CACHE BOOL "" FORCE)
set(CEF_RUNTIME_LIBRARY_FLAG "/MD" CACHE STRING "" FORCE)

# Configure the CEF build environment from the standard distribution.
set(CEF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "webview_cef_plugin")

# Build the CEF C++ wrapper library from source.
add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "webview_cef_plugin.cpp"
  "webview_cef_plugin.h"
  "webview_cef_keyevent.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_app.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_app.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_handler.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_handler.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_plugin.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_plugin.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_value.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_value.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_js_handler.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_js_handler.h"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_cookieVisitor.cc"
  "${CMAKE_CURRENT_LIST_DIR}/../common/webview_cookieVisitor.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/webview_cef/webview_cef_plugin_c_api.h"
  "webview_cef_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# CEF 149 public headers (e.g. base/cef_scoped_refptr.h) require C++20. Raise
# the standard for the plugin and anything that links it (the runner includes
# CEF headers transitively through the C API header).
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_20)

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
# CEF/Chromium headers use std::min/std::max and numeric_limits::max(), which
# collide with the min/max macros from <windows.h>. Disable those macros.
target_compile_definitions(${PLUGIN_NAME} PRIVATE NOMINMAX)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CEF_ROOT}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common")

# Add the CEF library as a logical target (handles Debug/Release selection).
ADD_LOGICAL_TARGET("libcef_lib" "${CEF_LIB_DEBUG}" "${CEF_LIB_RELEASE}")
# Flutter's "Profile" configuration maps onto CEF's Release binaries.
set_target_properties(libcef_lib PROPERTIES MAP_IMPORTED_CONFIG_PROFILE Release)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  libcef_lib
  libcef_dll_wrapper)

# === Bundle the CEF runtime next to the application executable. ===
# Binaries are configuration-specific (Debug vs Release); every non-Debug
# configuration (including Flutter's Profile) uses the Release binaries.
set(_cef_bin_dir "$<IF:$<CONFIG:Debug>,${CEF_BINARY_DIR_DEBUG},${CEF_BINARY_DIR_RELEASE}>")

set(webview_cef_bundled_libraries "")
foreach(_cef_file ${CEF_BINARY_FILES})
  list(APPEND webview_cef_bundled_libraries "${_cef_bin_dir}/${_cef_file}")
endforeach()
# Resource .pak / .dat files are configuration-independent. "locales" is a
# directory; the Flutter install(FILES ...) step copies it recursively (CMake's
# file(INSTALL) handles directory entries), preserving the locales/ subfolder.
foreach(_cef_file ${CEF_RESOURCE_FILES})
  list(APPEND webview_cef_bundled_libraries "${CEF_RESOURCE_DIR}/${_cef_file}")
endforeach()

# List of absolute paths to libraries that should be bundled with the plugin.
set(webview_cef_bundled_libraries
  ${webview_cef_bundled_libraries}
  PARENT_SCOPE
)
