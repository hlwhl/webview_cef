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
  s.vendored_frameworks = 'third/cef/Chromium Embedded Framework.framework'
  s.vendored_libraries = 'third/cef/libcef_dll_wrapper.a'

  $dir = File.dirname(__FILE__)
  $dir = $dir + "/third/cef/**"
  s.xcconfig = { "HEADER_SEARCH_PATHS" => $dir}
  # s.private_header_files = '../common/simple_app.h', '../common/simple_handler.h'

  s.platform = :osx, '10.15'
  # CEF 149 public headers require C++20.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20' }
  s.swift_version = '5.0'
end
