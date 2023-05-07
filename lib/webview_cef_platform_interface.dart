import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'webview_cef_method_channel.dart';

abstract class WebviewCefPlatform extends PlatformInterface {
  /// Constructs a WebviewCefPlatform.
  WebviewCefPlatform() : super(token: _token);

  static final Object _token = Object();

  static WebviewCefPlatform _instance = MethodChannelWebviewCef();

  /// The default instance of [WebviewCefPlatform] to use.
  ///
  /// Defaults to [MethodChannelWebviewCef].
  static WebviewCefPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WebviewCefPlatform] when
  /// they register themselves.
  static set instance(WebviewCefPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
