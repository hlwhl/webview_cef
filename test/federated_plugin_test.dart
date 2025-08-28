import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef.dart';
import 'package:webview_cef/webview_cef_platform_interface.dart';
import 'package:webview_cef/webview_cef_method_channel.dart';

void main() {
  group('Federated Plugin Architecture', () {
    test('Platform interface is properly set up', () {
      // Verify that the default instance is the method channel implementation
      expect(WebviewCefPlatform.instance, isA<MethodChannelWebviewCef>());
    });

    test('WebviewManager uses platform interface', () {
      // Create a WebviewManager instance
      final manager = WebviewManager();
      
      // Verify it's a ValueNotifier<bool> (initial state)
      expect(manager, isA<ValueNotifier<bool>>());
      expect(manager.value, false); // Should be false before initialization
    });

    test('WebViewController can be created through WebviewManager', () {
      final manager = WebviewManager();
      
      // Create a webview controller
      final controller = manager.createWebView();
      
      // Verify it's properly created
      expect(controller, isA<WebViewController>());
      expect(controller.value, false); // Should be false before initialization
    });

    test('WebviewCef API is accessible', () {
      final api = WebviewCef();
      
      // Verify the API object is created
      expect(api, isA<WebviewCef>());
      
      // The API should have access to platform methods
      expect(() => api.getPlatformVersion(), returnsNormally);
    });
  });
}