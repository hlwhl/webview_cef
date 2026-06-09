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

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
