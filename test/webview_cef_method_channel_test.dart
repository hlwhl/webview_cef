import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef_method_channel.dart';

void main() {
  MethodChannelWebviewCef platform = MethodChannelWebviewCef();
  const MethodChannel channel = MethodChannel('webview_cef');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return '42';
        case 'init':
          return null;
        case 'create':
          return [1, 2]; // browserId, textureId
        case 'close':
          return null;
        case 'loadUrl':
          return null;
        case 'reload':
          return null;
        case 'goBack':
          return null;
        case 'goForward':
          return null;
        case 'openDevTools':
          return null;
        case 'executeJavaScript':
          return null;
        case 'evaluateJavascript':
          return 'result';
        case 'setJavaScriptChannels':
          return null;
        case 'sendJavaScriptChannelCallBack':
          return null;
        case 'setSize':
          return null;
        case 'cursorMove':
          return null;
        case 'cursorClickDown':
          return null;
        case 'cursorClickUp':
          return null;
        case 'cursorDragging':
          return null;
        case 'setScrollDelta':
          return null;
        case 'setClientFocus':
          return null;
        case 'imeSetComposition':
          return null;
        case 'imeCommitText':
          return null;
        case 'setCookie':
          return null;
        case 'deleteCookie':
          return null;
        case 'visitAllCookies':
          return {};
        case 'visitUrlCookies':
          return {};
        case 'quit':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('initialize', () async {
    await platform.initialize(userAgent: 'test-agent');
    // Should complete without throwing
  });

  test('createWebview', () async {
    final result = await platform.createWebview('https://example.com');
    expect(result, [1, 2]);
  });

  test('loadUrl', () async {
    await platform.loadUrl(1, 'https://example.com');
    // Should complete without throwing
  });

  test('evaluateJavascript', () async {
    final result = await platform.evaluateJavascript(1, 'console.log("test")');
    expect(result, 'result');
  });

  test('visitAllCookies', () async {
    final result = await platform.visitAllCookies();
    expect(result, {});
  });
}
