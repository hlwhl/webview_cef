
import 'webview_cef_platform_interface.dart';

class WebviewCef {
  Future<String?> getPlatformVersion() {
    return WebviewCefPlatform.instance.getPlatformVersion();
  }
}
