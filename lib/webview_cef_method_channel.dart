import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'webview_cef_platform_interface.dart';

/// An implementation of [WebviewCefPlatform] that uses method channels.
class MethodChannelWebviewCef extends WebviewCefPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('webview_cef');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> initialize({String? userAgent}) async {
    if (userAgent != null && userAgent.isNotEmpty) {
      await methodChannel.invokeMethod('init', userAgent);
    } else {
      await methodChannel.invokeMethod('init');
    }
  }

  @override
  Future<List<int>> createWebview(String url) async {
    final result = await methodChannel.invokeMethod('create', url);
    return List<int>.from(result);
  }

  @override
  Future<void> closeWebview(int browserId) async {
    await methodChannel.invokeMethod('close', browserId);
  }

  @override
  Future<void> loadUrl(int browserId, String url) async {
    await methodChannel.invokeMethod('loadUrl', [browserId, url]);
  }

  @override
  Future<void> reload(int browserId) async {
    await methodChannel.invokeMethod('reload', browserId);
  }

  @override
  Future<void> goBack(int browserId) async {
    await methodChannel.invokeMethod('goBack', browserId);
  }

  @override
  Future<void> goForward(int browserId) async {
    await methodChannel.invokeMethod('goForward', browserId);
  }

  @override
  Future<void> openDevTools(int browserId) async {
    await methodChannel.invokeMethod('openDevTools', browserId);
  }

  @override
  Future<void> executeJavaScript(int browserId, String code) async {
    await methodChannel.invokeMethod('executeJavaScript', [browserId, code]);
  }

  @override
  Future<dynamic> evaluateJavascript(int browserId, String code) async {
    return await methodChannel.invokeMethod('evaluateJavascript', [browserId, code]);
  }

  @override
  Future<void> setJavaScriptChannels(int browserId, List<String> channelNames) async {
    await methodChannel.invokeMethod('setJavaScriptChannels', [browserId, channelNames]);
  }

  @override
  Future<void> sendJavaScriptChannelCallBack(bool error, String result, String callbackId, int browserId, String frameId) async {
    await methodChannel.invokeMethod('sendJavaScriptChannelCallBack', [error, result, callbackId, browserId, frameId]);
  }

  @override
  Future<void> setSize(int browserId, double dpi, double width, double height) async {
    await methodChannel.invokeMethod('setSize', [browserId, dpi, width, height]);
  }

  @override
  Future<void> cursorMove(int browserId, int x, int y) async {
    await methodChannel.invokeMethod('cursorMove', [browserId, x, y]);
  }

  @override
  Future<void> cursorClickDown(int browserId, int x, int y) async {
    await methodChannel.invokeMethod('cursorClickDown', [browserId, x, y]);
  }

  @override
  Future<void> cursorClickUp(int browserId, int x, int y) async {
    await methodChannel.invokeMethod('cursorClickUp', [browserId, x, y]);
  }

  @override
  Future<void> cursorDragging(int browserId, int x, int y) async {
    await methodChannel.invokeMethod('cursorDragging', [browserId, x, y]);
  }

  @override
  Future<void> setScrollDelta(int browserId, int x, int y, int dx, int dy) async {
    await methodChannel.invokeMethod('setScrollDelta', [browserId, x, y, dx, dy]);
  }

  @override
  Future<void> setClientFocus(int browserId, bool focus) async {
    await methodChannel.invokeMethod('setClientFocus', [browserId, focus]);
  }

  @override
  Future<void> imeSetComposition(int browserId, String composingText) async {
    await methodChannel.invokeMethod('imeSetComposition', [browserId, composingText]);
  }

  @override
  Future<void> imeCommitText(int browserId, String composingText) async {
    await methodChannel.invokeMethod('imeCommitText', [browserId, composingText]);
  }

  @override
  Future<void> setCookie(String domain, String key, String value) async {
    await methodChannel.invokeMethod('setCookie', [domain, key, value]);
  }

  @override
  Future<void> deleteCookie(String domain, String key) async {
    await methodChannel.invokeMethod('deleteCookie', [domain, key]);
  }

  @override
  Future<dynamic> visitAllCookies() async {
    return await methodChannel.invokeMethod('visitAllCookies');
  }

  @override
  Future<dynamic> visitUrlCookies(String domain, bool isHttpOnly) async {
    return await methodChannel.invokeMethod('visitUrlCookies', [domain, isHttpOnly]);
  }

  @override
  Future<void> quit() async {
    await methodChannel.invokeMethod('quit');
  }

  @override
  void setMethodCallHandler(Future<void> Function(MethodCall call)? handler) {
    methodChannel.setMethodCallHandler(handler);
  }
}
