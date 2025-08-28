import 'package:webview_cef/webview_cef_platform_interface.dart';

/// Main API class for webview_cef plugin
/// This provides a simple interface that uses the federated plugin architecture
class WebviewCef {
  static WebviewCefPlatform get _platform => WebviewCefPlatform.instance;

  /// Get the platform version
  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }
}