import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef.dart';
import 'package:webview_cef/webview_cef_platform_interface.dart';
import 'package:webview_cef/webview_cef_method_channel.dart';

void main() {
  group('Complete Federated Plugin Integration', () {
    late List<MethodCall> log;
    
    setUp(() {
      log = <MethodCall>[];
      // Mock all method channel calls
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('webview_cef'),
        (MethodCall methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case 'getPlatformVersion':
              return '1.0.0';
            case 'init':
              return null;
            case 'create':
              return [1, 2]; // browserId, textureId
            case 'close':
              return null;
            case 'loadUrl':
              return null;
            case 'executeJavaScript':
              return null;
            case 'evaluateJavascript':
              return 'test result';
            case 'setCookie':
              return null;
            case 'visitAllCookies':
              return {'test.com': {'sessionid': 'abc123'}};
            case 'quit':
              return null;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('webview_cef'), null);
    });

    test('WebviewCef API works with platform interface', () async {
      final api = WebviewCef();
      
      final version = await api.getPlatformVersion();
      expect(version, '1.0.0');
      expect(log, hasLength(1));
      expect(log[0].method, 'getPlatformVersion');
    });

    test('WebviewManager initializes through platform interface', () async {
      final manager = WebviewManager();
      
      await manager.initialize(userAgent: 'TestAgent');
      expect(manager.value, true);
      
      // Should have called init method
      expect(log.any((call) => call.method == 'init'), true);
      final initCall = log.firstWhere((call) => call.method == 'init');
      expect(initCall.arguments, 'TestAgent');
    });

    test('WebviewManager cookie operations use platform interface', () async {
      final manager = WebviewManager();
      await manager.initialize();
      
      log.clear(); // Clear initialization calls
      
      // Test cookie operations
      await manager.setCookie('test.com', 'sessionid', 'abc123');
      await manager.visitAllCookies();
      
      expect(log, hasLength(2));
      expect(log[0].method, 'setCookie');
      expect(log[0].arguments, ['test.com', 'sessionid', 'abc123']);
      expect(log[1].method, 'visitAllCookies');
    });

    test('WebViewController uses platform interface for all operations', () async {
      final manager = WebviewManager();
      await manager.initialize();
      
      final controller = manager.createWebView();
      await controller.initialize('https://example.com');
      
      log.clear(); // Clear previous calls
      
      // Test various operations
      await controller.loadUrl('https://google.com');
      await controller.executeJavaScript('console.log("test")');
      final result = await controller.evaluateJavascript('2 + 2');
      
      expect(log, hasLength(3));
      expect(log[0].method, 'loadUrl');
      expect(log[0].arguments, [1, 'https://google.com']);
      expect(log[1].method, 'executeJavaScript');
      expect(log[1].arguments, [1, 'console.log("test")']);
      expect(log[2].method, 'evaluateJavascript');
      expect(log[2].arguments, [1, '2 + 2']);
      expect(result, 'test result');
    });

    test('Platform interface can be replaced for testing', () async {
      // Create a mock platform
      final originalPlatform = WebviewCefPlatform.instance;
      
      try {
        final mockPlatform = MockWebviewCefPlatform();
        WebviewCefPlatform.instance = mockPlatform;
        
        final api = WebviewCef();
        final version = await api.getPlatformVersion();
        
        expect(version, 'mock version');
        // Should not have called the real method channel
        expect(log, isEmpty);
      } finally {
        // Restore original platform
        WebviewCefPlatform.instance = originalPlatform;
      }
    });
  });
}

class MockWebviewCefPlatform extends WebviewCefPlatform {
  @override
  Future<String?> getPlatformVersion() async => 'mock version';

  @override
  Future<void> initialize({String? userAgent}) async {}

  @override
  Future<List<int>> createWebview(String url) async => [99, 100];

  @override
  Future<void> closeWebview(int browserId) async {}

  @override
  Future<void> loadUrl(int browserId, String url) async {}

  @override
  Future<void> reload(int browserId) async {}

  @override
  Future<void> goBack(int browserId) async {}

  @override
  Future<void> goForward(int browserId) async {}

  @override
  Future<void> openDevTools(int browserId) async {}

  @override
  Future<void> executeJavaScript(int browserId, String code) async {}

  @override
  Future<dynamic> evaluateJavascript(int browserId, String code) async => 'mock result';

  @override
  Future<void> setJavaScriptChannels(int browserId, List<String> channelNames) async {}

  @override
  Future<void> sendJavaScriptChannelCallBack(bool error, String result, String callbackId, int browserId, String frameId) async {}

  @override
  Future<void> setSize(int browserId, double dpi, double width, double height) async {}

  @override
  Future<void> cursorMove(int browserId, int x, int y) async {}

  @override
  Future<void> cursorClickDown(int browserId, int x, int y) async {}

  @override
  Future<void> cursorClickUp(int browserId, int x, int y) async {}

  @override
  Future<void> cursorDragging(int browserId, int x, int y) async {}

  @override
  Future<void> setScrollDelta(int browserId, int x, int y, int dx, int dy) async {}

  @override
  Future<void> setClientFocus(int browserId, bool focus) async {}

  @override
  Future<void> imeSetComposition(int browserId, String composingText) async {}

  @override
  Future<void> imeCommitText(int browserId, String composingText) async {}

  @override
  Future<void> setCookie(String domain, String key, String value) async {}

  @override
  Future<void> deleteCookie(String domain, String key) async {}

  @override
  Future<dynamic> visitAllCookies() async => {'mock.com': {'test': 'value'}};

  @override
  Future<dynamic> visitUrlCookies(String domain, bool isHttpOnly) async => {};

  @override
  Future<void> quit() async {}

  @override
  void setMethodCallHandler(Future<void> Function(MethodCall call)? handler) {}
}