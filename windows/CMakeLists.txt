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

include(${CMAKE_CURRENT_SOURCE_DIR}/../third/download.cmake)
# wait for unified version cef source code and prebuilt files
prepare_prebuilt_files(${CMAKE_CURRENT_SOURCE_DIR}/../third/cef)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "webview_cef_plugin")

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

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third/cef)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../common)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
debug ${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/libcef.lib
debug ${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/libcef_dll_wrapper.lib
optimized ${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/libcef.lib
optimized ${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/libcef_dll_wrapper.lib)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(webview_cef_bundled_libraries
    "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/resources/locales"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/resources/icudtl.dat"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/resources/resources.pak"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/resources/chrome_100_percent.pak"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/resources/chrome_200_percent.pak"
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/chrome_elf.dll>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/libcef.dll>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/v8_context_snapshot.bin>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/swiftshader>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/d3dcompiler_47.dll>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/libEGL.dll>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/libGLESv2.dll>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/vulkan-1.dll>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/vk_swiftshader.dll>
    $<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/debug/bin/vk_swiftshader_icd.json>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/chrome_elf.dll>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/libcef.dll>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/v8_context_snapshot.bin>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/swiftshader>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/d3dcompiler_47.dll>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/libEGL.dll>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/libGLESv2.dll>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/vulkan-1.dll>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/vk_swiftshader.dll>
    $<$<CONFIG:Release>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/vk_swiftshader_icd.json>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/chrome_elf.dll>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/libcef.dll>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/v8_context_snapshot.bin>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/swiftshader>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/d3dcompiler_47.dll>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/libEGL.dll>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/libGLESv2.dll>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/vulkan-1.dll>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/vk_swiftshader.dll>
    $<$<CONFIG:Profile>:${CMAKE_CURRENT_SOURCE_DIR}/../third/cef/release/bin/vk_swiftshader_icd.json>
    PARENT_SCOPE)

