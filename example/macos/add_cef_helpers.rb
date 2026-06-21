#!/usr/bin/env ruby
# Adds a CEF Helper app target to the example Runner project and an embed phase
# that produces the 5 macOS helper bundles inside Runner.app/Contents/Frameworks.
# Idempotent: re-running removes the previous additions first.
require "xcodeproj"

PROJ = File.join(__dir__, "Runner.xcodeproj")
HELPER_NAME = "webview_cef_example Helper"
HELPER_BUNDLE_ID = "com.electronicdream.webviewCefExample.helper"
EMBED_PHASE_NAME = "Embed CEF Helpers"

project = Xcodeproj::Project.open(PROJ)
runner = project.native_targets.find { |t| t.name == "Runner" }
raise "Runner target not found" unless runner

# --- clean previous additions (idempotent) ----------------------------------
# Remove Runner's dependency on Helper (and any dangling deps) FIRST, while the
# target still resolves — otherwise it becomes a nil-target dep that crashes
# xcodeproj's add_dependency dedup later.
runner.dependencies.dup.each do |d|
  if d.target.nil? || d.target.name == "Helper"
    runner.dependencies.delete(d)
    d.remove_from_project
  end
end
runner.build_phases.select { |ph|
  ph.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && ph.name == EMBED_PHASE_NAME
}.each { |ph| runner.build_phases.delete(ph) }
project.native_targets.select { |t| t.name == "Helper" }.each(&:remove_from_project)

# --- create the Helper application target ------------------------------------
helper = project.new_target(:application, "Helper", :osx, "11.0")
helper.build_configuration_list.build_configurations.each do |c|
  s = c.build_settings
  s["PRODUCT_NAME"] = HELPER_NAME
  s["PRODUCT_BUNDLE_IDENTIFIER"] = HELPER_BUNDLE_ID
  s["INFOPLIST_FILE"] = "Runner/Helper-Info.plist"
  s["CODE_SIGN_ENTITLEMENTS"] = "Runner/Helper.entitlements"
  s["CODE_SIGN_STYLE"] = "Automatic"
  s["MACOSX_DEPLOYMENT_TARGET"] = "11.0"
  s["CLANG_CXX_LANGUAGE_STANDARD"] = "c++20"
  s["CLANG_CXX_LIBRARY"] = "libc++"
  s["ENABLE_HARDENED_RUNTIME"] = "NO"
  s["ALWAYS_SEARCH_USER_PATHS"] = "NO"
  s["COMBINE_HIDPI_IMAGES"] = "YES"
  s["SKIP_INSTALL"] = "YES"
  s["HEADER_SEARCH_PATHS"] = ["$(inherited)",
                              "$(SRCROOT)/../../macos/third/cef",
                              "$(SRCROOT)/../../common"]
  # libcef_dll_wrapper pulls in Obj-C categories (mac library loader); -ObjC
  # force-loads them. Framework itself is dlopen'd at runtime (LoadInHelper).
  # Deliberately NOT inheriting: the Runner/Pods OTHER_LDFLAGS link the CEF and
  # webview_cef frameworks, which the helper must not link (and whose
  # space-containing name breaks the linker when inherited here).
  s["OTHER_LDFLAGS"] = ["-ObjC", "-framework", "Foundation", "-framework", "AppKit"]
end

# Source: the helper entry (it #includes the shared common/*.cc unity).
runner_group = project.main_group["Runner"]
helper_src = runner_group.find_file_by_path("cef_helper_main.mm") ||
             runner_group.new_file("cef_helper_main.mm")
helper.source_build_phase.add_file_reference(helper_src)

# Link the prebuilt wrapper static lib (built by macos/scripts/download_cef.sh).
wrapper_path = "../../macos/third/cef/libcef_dll_wrapper.a"
frameworks_group = project.frameworks_group
wrapper_ref = frameworks_group.files.find { |f| f.path == wrapper_path } ||
              frameworks_group.new_file(wrapper_path)
helper.frameworks_build_phase.add_file_reference(wrapper_ref)

# --- embed phase on Runner: build the 5 helper bundles + sign ----------------
script = <<~SH
  set -e
  BASE="#{HELPER_NAME}"
  SRC="${BUILT_PRODUCTS_DIR}/${BASE}.app"
  DEST="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
  ENT="${SRCROOT}/Runner/Helper.entitlements"
  IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
  mkdir -p "${DEST}"

  # "<name suffix>:<bundle-id suffix>" — see CEF_HELPER_APP_SUFFIXES.
  for spec in ":" " (GPU):.gpu" " (Plugin):.plugin" " (Renderer):.renderer" " (Alerts):.alerts"; do
    suffix="${spec%%:*}"
    idsuffix="${spec##*:}"
    name="${BASE}${suffix}"
    app="${DEST}/${name}.app"
    rm -rf "${app}"
    /bin/cp -R "${SRC}" "${app}"
    if [ "${suffix}" != "" ]; then
      /bin/mv "${app}/Contents/MacOS/${BASE}" "${app}/Contents/MacOS/${name}"
    fi
    plist="${app}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${name}" "${plist}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${name}" "${plist}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName ${name}" "${plist}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier #{HELPER_BUNDLE_ID}${idsuffix}" "${plist}"
    /usr/bin/codesign --force --sign "${IDENTITY}" --entitlements "${ENT}" --timestamp=none "${app}"
  done
SH

phase = runner.new_shell_script_build_phase(EMBED_PHASE_NAME)
phase.shell_script = script
phase.shell_path = "/bin/bash"

# Ensure Helper builds before Runner embeds it.
runner.add_dependency(helper)

project.save
puts "OK: added Helper target + '#{EMBED_PHASE_NAME}' phase."
