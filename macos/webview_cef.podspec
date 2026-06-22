#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint webview_cef.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'webview_cef'
  s.version          = '0.2.3'
  s.summary          = 'Flutter webview backed by CEF (Chromium Embedded Framework)'
  s.description      = <<-DESC
Flutter webview backed by CEF (Chromium Embedded Framework)
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  # CEF is not tracked in git for macOS (mirrors the Windows/Linux CMake
  # download path in third/download.cmake). It is fetched and the wrapper built
  # on demand into third/cef. Runs on every `pod install`; a no-op once the
  # pinned version is present. Override build type via CEF_WRAPPER_BUILD_TYPE.
  s.prepare_command = 'bash scripts/download_cef.sh'

  s.vendored_frameworks = 'third/cef/Chromium Embedded Framework.framework'
  s.vendored_libraries = 'third/cef/libcef_dll_wrapper.a'

  $dir = File.dirname(__FILE__)
  $dir = $dir + "/third/cef/**"
  s.xcconfig = { "HEADER_SEARCH_PATHS" => $dir}
  # s.private_header_files = '../common/simple_app.h', '../common/simple_handler.h'

  # CEF ships separate per-architecture macOS binaries; scripts/download_cef.sh
  # fetches the one matching the build host (arm64 -> macosarm64, x86_64 ->
  # macosx64). Exclude the other architecture so a default (universal)
  # `flutter build macos` doesn't try to link a slice the CEF framework/wrapper
  # doesn't provide — that fails with "symbol(s) not found for architecture
  # x86_64". A universal app would require a lipo'd CEF, which is out of scope.
  host_arch = `uname -m`.strip
  non_host_arch = (host_arch == 'arm64') ? 'x86_64' : 'arm64'

  s.platform = :osx, '12.0'
  # CEF 149 public headers require C++20.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    "EXCLUDED_ARCHS[sdk=macosx*]" => non_host_arch,
    # Zero-copy GPU rendering: CEF delivers frames as a shared-texture IOSurface
    # via OnAcceleratedPaint instead of a software CPU buffer (OnPaint). The IME
    # and frame plumbing key off this define in the shared common/ sources.
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) WEBVIEW_CEF_GPU_TEXTURE=1',
  }
  # The app target links the CEF framework/wrapper too, so it must drop the same
  # architecture or its slice fails to link.
  s.user_target_xcconfig = { "EXCLUDED_ARCHS[sdk=macosx*]" => non_host_arch }
  s.swift_version = '5.0'
end
