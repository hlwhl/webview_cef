import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef.dart';
import 'package:webview_cef/webview_cef_platform_interface.dart';
import 'package:webview_cef/webview_cef_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWebviewCefPlatform
    with MockPlatformInterfaceMixin
    implements WebviewCefPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WebviewCefPlatform initialPlatform = WebviewCefPlatform.instance;

  test('$MethodChannelWebviewCef is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWebviewCef>());
  });

  test('getPlatformVersion', () async {
    WebviewCef webviewCefPlugin = WebviewCef();
    MockWebviewCefPlatform fakePlatform = MockWebviewCefPlatform();
    WebviewCefPlatform.instance = fakePlatform;

    expect(await webviewCefPlugin.getPlatformVersion(), '42');
  });
}
