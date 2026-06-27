#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint webview_cef.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'webview_cef'
  s.version          = '0.0.8'
  s.summary          = 'Flutter webview backed by CEF (Chromium Embedded Framework)'
  s.description      = <<-DESC
Flutter Desktop WebView backed by CEF (Chromium Embedded Framework).
                       DESC
  s.homepage         = 'https://github.com/hlwhl/webview_cef'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'webview_cef' => 'https://github.com/hlwhl/webview_cef' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  # Ensure the prebuilt CEF binaries are present before the vendored artifacts
  # below are evaluated. CocoaPods' `prepare_command` is skipped for path /
  # development pods (how Flutter plugins install), so the download is triggered
  # here from the podspec itself. The script is idempotent and a no-op once CEF
  # is installed. Override the architecture with WEBVIEW_CEF_MACOS_ARCH.
  cef_framework = File.join(File.dirname(__FILE__), 'third', 'cef', 'Chromium Embedded Framework.framework')
  unless File.directory?(cef_framework)
    system('bash', File.join(File.dirname(__FILE__), 'scripts', 'download_cef.sh')) or
      raise 'webview_cef: failed to download the macOS CEF binaries. See the macOS setup section of the README for the manual fallback.'
  end

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
