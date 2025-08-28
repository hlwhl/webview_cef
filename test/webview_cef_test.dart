import 'package:flutter/services.dart';
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

  @override
  Future<void> initialize({String? userAgent}) => Future.value();

  @override
  Future<List<int>> createWebview(String url) => Future.value([1, 2]);

  @override
  Future<void> closeWebview(int browserId) => Future.value();

  @override
  Future<void> loadUrl(int browserId, String url) => Future.value();

  @override
  Future<void> reload(int browserId) => Future.value();

  @override
  Future<void> goBack(int browserId) => Future.value();

  @override
  Future<void> goForward(int browserId) => Future.value();

  @override
  Future<void> openDevTools(int browserId) => Future.value();

  @override
  Future<void> executeJavaScript(int browserId, String code) => Future.value();

  @override
  Future<dynamic> evaluateJavascript(int browserId, String code) => Future.value('result');

  @override
  Future<void> setJavaScriptChannels(int browserId, List<String> channelNames) => Future.value();

  @override
  Future<void> sendJavaScriptChannelCallBack(bool error, String result, String callbackId, int browserId, String frameId) => Future.value();

  @override
  Future<void> setSize(int browserId, double dpi, double width, double height) => Future.value();

  @override
  Future<void> cursorMove(int browserId, int x, int y) => Future.value();

  @override
  Future<void> cursorClickDown(int browserId, int x, int y) => Future.value();

  @override
  Future<void> cursorClickUp(int browserId, int x, int y) => Future.value();

  @override
  Future<void> cursorDragging(int browserId, int x, int y) => Future.value();

  @override
  Future<void> setScrollDelta(int browserId, int x, int y, int dx, int dy) => Future.value();

  @override
  Future<void> setClientFocus(int browserId, bool focus) => Future.value();

  @override
  Future<void> imeSetComposition(int browserId, String composingText) => Future.value();

  @override
  Future<void> imeCommitText(int browserId, String composingText) => Future.value();

  @override
  Future<void> setCookie(String domain, String key, String value) => Future.value();

  @override
  Future<void> deleteCookie(String domain, String key) => Future.value();

  @override
  Future<dynamic> visitAllCookies() => Future.value({});

  @override
  Future<dynamic> visitUrlCookies(String domain, bool isHttpOnly) => Future.value({});

  @override
  Future<void> quit() => Future.value();

  @override
  void setMethodCallHandler(Future<void> Function(MethodCall call)? handler) {}
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
