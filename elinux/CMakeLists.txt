cmake_minimum_required(VERSION 3.10)

cmake_policy(SET CMP0074 NEW)

set(PROJECT_NAME "webview_cef")
project(${PROJECT_NAME} LANGUAGES CXX C)
set(CMAKE_CXX_STANDARD 17)

# Setup CEF
include(${CMAKE_CURRENT_SOURCE_DIR}/../third/download.cmake)
prepare_prebuilt_files(${CMAKE_CURRENT_SOURCE_DIR}/../third/cef)

# Explicitly set PROJECT_ARCH for CEF before find_package
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64" OR
   CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64" OR
   CMAKE_CXX_COMPILER_TARGET MATCHES "aarch64" OR
   CMAKE_CXX_COMPILER_TARGET MATCHES "arm64")
    set(PROJECT_ARCH "arm64")
elseif(CMAKE_SIZEOF_VOID_P MATCHES 8)
    set(PROJECT_ARCH "x86_64")
else()
    set(PROJECT_ARCH "x86")
endif()

set(CEF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../third/cef")
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)

set(PLUGIN_NAME "webview_cef_plugin")

add_library(${PLUGIN_NAME} SHARED
  "webview_cef_plugin.cc"
  "webview_cef_texture.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_app.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_app.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_handler.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_handler.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_plugin.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_plugin.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_value.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_value.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_js_handler.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_js_handler.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_cookieVisitor.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../common/webview_cookieVisitor.h"
)

# Include the C++ client wrapper.
set(FLUTTER_CPP_CLIENT_WRAPPER "${CMAKE_CURRENT_SOURCE_DIR}/../example/elinux/flutter/ephemeral/cpp_client_wrapper")
target_include_directories(${PLUGIN_NAME} PRIVATE "${FLUTTER_CPP_CLIENT_WRAPPER}/include")
# Add ephemeral dir so <flutter_elinux/flutter_elinux.h> resolves correctly
target_include_directories(${PLUGIN_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../example/elinux/flutter/ephemeral")
target_include_directories(${PLUGIN_NAME} PRIVATE 
  "${CMAKE_CURRENT_SOURCE_DIR}/../example/elinux/flutter/ephemeral"
  "../third/cef"
)
target_sources(${PLUGIN_NAME} PRIVATE
  "${FLUTTER_CPP_CLIENT_WRAPPER}/standard_codec.cc"
  "${FLUTTER_CPP_CLIENT_WRAPPER}/plugin_registrar.cc"
  "${FLUTTER_CPP_CLIENT_WRAPPER}/engine_method_result.cc"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  flutter
  libcef_dll_wrapper
  ${CEF_LIB_DEPS}
)
# The flutter target here refers to the library provided by the elinux toolchain
# which is automatically configured in the example/elinux build.
# Note: GTK and X11 dependencies are removed to support DRM/GBM/Wayland.

target_include_directories(${PLUGIN_NAME} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/../common")

#########################################cef#########################################
set(CEF_TARGET ${PLUGIN_NAME})
ADD_LOGICAL_TARGET("libcef_lib" "${CEF_LIB_DEBUG}" "${CEF_LIB_RELEASE}")
SET_CEF_TARGET_OUT_DIR()
add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)

SET_EXECUTABLE_TARGET_PROPERTIES(${CEF_TARGET})
add_dependencies(${CEF_TARGET} libcef_dll_wrapper)
target_link_libraries(${CEF_TARGET} PUBLIC libcef_lib libcef_dll_wrapper ${CEF_STANDARD_LIBS})

set_target_properties(${CEF_TARGET} PROPERTIES INSTALL_RPATH "$ORIGIN")
set_target_properties(${CEF_TARGET} PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE)
set_target_properties(${CEF_TARGET} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CEF_TARGET_OUT_DIR})

set(INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV "${PROJECT_BINARY_DIR}")
get_filename_component(INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV "${INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV}" DIRECTORY)
get_filename_component(INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV "${INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV}" DIRECTORY)
set(INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV "${INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV}/bundle/lib")

set(cef_library_list "")
foreach(FILE ${CEF_BINARY_FILES})
  list(APPEND cef_library_list ${CEF_BINARY_DIR}/${FILE})
endforeach()

foreach(FILE ${CEF_RESOURCE_FILES})
  if(IS_DIRECTORY "${CEF_RESOURCE_DIR}/${FILE}")
    # Ensure we copy the contents of the directory (like locales/*.pak)
    install(DIRECTORY "${CEF_RESOURCE_DIR}/${FILE}/"
            DESTINATION "${INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV}/${FILE}"
            COMPONENT Runtime)
  else()
    list(APPEND cef_library_list "${CEF_RESOURCE_DIR}/${FILE}")
  endif()
endforeach(FILE)
#######################################cef end#######################################

# Copy locales directory into bundle/lib/locales
file(GLOB CEF_LOCALE_FILES "${CEF_RESOURCE_DIR}/locales/*.pak")
foreach(LOCALE_FILE ${CEF_LOCALE_FILES})
  install(FILES "${LOCALE_FILE}"
          DESTINATION "${INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV}/locales"
          COMPONENT Runtime)
endforeach()

# Also copy at build time so it works without cmake --install
add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory
    "${INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV}/locales"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CEF_RESOURCE_DIR}/locales"
    "${INSTALL_BUNDLE_APPLICATION_DIR_WEBVIEW_CEV}/locales"
  COMMENT "Copying CEF locales to bundle"
)

set(webview_cef_bundled_libraries
  ""
  ${cef_library_list}
  PARENT_SCOPE
)
