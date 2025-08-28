import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter/services.dart';

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

  /// Initialize the CEF webview system
  Future<void> initialize({String? userAgent}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Create a new webview instance
  Future<List<int>> createWebview(String url) {
    throw UnimplementedError('createWebview() has not been implemented.');
  }

  /// Close a webview instance
  Future<void> closeWebview(int browserId) {
    throw UnimplementedError('closeWebview() has not been implemented.');
  }

  /// Load a URL in the webview
  Future<void> loadUrl(int browserId, String url) {
    throw UnimplementedError('loadUrl() has not been implemented.');
  }

  /// Reload the current page
  Future<void> reload(int browserId) {
    throw UnimplementedError('reload() has not been implemented.');
  }

  /// Go back in navigation history
  Future<void> goBack(int browserId) {
    throw UnimplementedError('goBack() has not been implemented.');
  }

  /// Go forward in navigation history
  Future<void> goForward(int browserId) {
    throw UnimplementedError('goForward() has not been implemented.');
  }

  /// Open developer tools
  Future<void> openDevTools(int browserId) {
    throw UnimplementedError('openDevTools() has not been implemented.');
  }

  /// Execute JavaScript code
  Future<void> executeJavaScript(int browserId, String code) {
    throw UnimplementedError('executeJavaScript() has not been implemented.');
  }

  /// Evaluate JavaScript code and return result
  Future<dynamic> evaluateJavascript(int browserId, String code) {
    throw UnimplementedError('evaluateJavascript() has not been implemented.');
  }

  /// Set JavaScript channels
  Future<void> setJavaScriptChannels(int browserId, List<String> channelNames) {
    throw UnimplementedError('setJavaScriptChannels() has not been implemented.');
  }

  /// Send JavaScript channel callback
  Future<void> sendJavaScriptChannelCallBack(bool error, String result, String callbackId, int browserId, String frameId) {
    throw UnimplementedError('sendJavaScriptChannelCallBack() has not been implemented.');
  }

  /// Set the webview size
  Future<void> setSize(int browserId, double dpi, double width, double height) {
    throw UnimplementedError('setSize() has not been implemented.');
  }

  /// Handle cursor movement
  Future<void> cursorMove(int browserId, int x, int y) {
    throw UnimplementedError('cursorMove() has not been implemented.');
  }

  /// Handle cursor click down
  Future<void> cursorClickDown(int browserId, int x, int y) {
    throw UnimplementedError('cursorClickDown() has not been implemented.');
  }

  /// Handle cursor click up
  Future<void> cursorClickUp(int browserId, int x, int y) {
    throw UnimplementedError('cursorClickUp() has not been implemented.');
  }

  /// Handle cursor dragging
  Future<void> cursorDragging(int browserId, int x, int y) {
    throw UnimplementedError('cursorDragging() has not been implemented.');
  }

  /// Set scroll delta
  Future<void> setScrollDelta(int browserId, int x, int y, int dx, int dy) {
    throw UnimplementedError('setScrollDelta() has not been implemented.');
  }

  /// Set client focus
  Future<void> setClientFocus(int browserId, bool focus) {
    throw UnimplementedError('setClientFocus() has not been implemented.');
  }

  /// Set IME composition
  Future<void> imeSetComposition(int browserId, String composingText) {
    throw UnimplementedError('imeSetComposition() has not been implemented.');
  }

  /// Commit IME text
  Future<void> imeCommitText(int browserId, String composingText) {
    throw UnimplementedError('imeCommitText() has not been implemented.');
  }

  /// Set a cookie
  Future<void> setCookie(String domain, String key, String value) {
    throw UnimplementedError('setCookie() has not been implemented.');
  }

  /// Delete a cookie
  Future<void> deleteCookie(String domain, String key) {
    throw UnimplementedError('deleteCookie() has not been implemented.');
  }

  /// Visit all cookies
  Future<dynamic> visitAllCookies() {
    throw UnimplementedError('visitAllCookies() has not been implemented.');
  }

  /// Visit URL cookies
  Future<dynamic> visitUrlCookies(String domain, bool isHttpOnly) {
    throw UnimplementedError('visitUrlCookies() has not been implemented.');
  }

  /// Quit the CEF application
  Future<void> quit() {
    throw UnimplementedError('quit() has not been implemented.');
  }

  /// Set the method call handler for receiving events from the platform
  void setMethodCallHandler(Future<void> Function(MethodCall call)? handler) {
    throw UnimplementedError('setMethodCallHandler() has not been implemented.');
  }
}
