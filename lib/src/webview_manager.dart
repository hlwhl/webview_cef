import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'webview.dart';

class WebviewManager extends ValueNotifier<bool> {
  static final WebviewManager _instance = WebviewManager._internal();

  factory WebviewManager() => _instance;

  late Completer<void> _creatingCompleter;

  final MethodChannel _pluginChannel = const MethodChannel("webview_cef");

  final Map<int, WebViewController> _webViews = <int, WebViewController>{};

  final Map<int, WebViewController> _tempWebViews = <int, WebViewController>{};

  int nextIndex = 1;

  get ready => _creatingCompleter.future;

  Map<String, dynamic> allCookies = {};

  String globalUserAgent = "";

  void setUserAgent(String userAgent) {
    globalUserAgent = userAgent;
  }

  void _handleVisitCookies(Map<String, dynamic> cookies) {
    for (final key in cookies.keys) {
      allCookies[key] = cookies[key];
    }
  }

  WebViewController createWebView(Widget? loading) {
    int browserIndex = nextIndex++;
    final controller =
        WebViewController(_pluginChannel, browserIndex, loading: loading);
    _tempWebViews[browserIndex] = controller;
    return controller;
  }

  WebViewController createWindow(Widget? loading) {
    //loading is not used now
    int browserIndex = nextIndex++;
    final controller = WebViewController(_pluginChannel, browserIndex,
        loading: loading, popup: true);
    _tempWebViews[browserIndex] = controller;
    return controller;
  }

  void removeWebView(int browserId) {
    if (browserId > 0) {
      _webViews.remove(browserId);
    }
  }

  WebviewManager._internal() : super(false);

  Future<void> initialize() async {
    _creatingCompleter = Completer<void>();
    try {
      await _pluginChannel.invokeMethod('init', globalUserAgent);
      _pluginChannel.setMethodCallHandler(_methodCallhandler);
      // Wait for the platform to complete initialization.
      await Future.delayed(const Duration(milliseconds: 300));
      _creatingCompleter.complete();
      value = true;
    } on PlatformException catch (e) {
      _creatingCompleter.completeError(e);
    }
    return _creatingCompleter.future;
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _pluginChannel.invokeMethod('dispose');
    _pluginChannel.setMethodCallHandler(null);
    _webViews.clear();
  }

  Future<void> _methodCallhandler(MethodCall call) async {
    switch (call.method) {
      case "browserCreated":
        int browserIndex = call.arguments["browserIndex"] as int;
        int browserId = call.arguments["browserId"] as int;
        _webViews[browserId] = _tempWebViews[browserIndex]!;
        _webViews[browserId]
            ?.onBrowserCreated(browserId, call.arguments["textureId"] as int);
        _tempWebViews.remove(browserIndex);
        return;
      case "urlChanged":
        int browserId = call.arguments["browserId"] as int;
        _webViews[browserId]
            ?.listener
            ?.onUrlChanged
            ?.call(call.arguments["url"] as String);
        return;
      case "titleChanged":
        int browserId = call.arguments["browserId"] as int;
        _webViews[browserId]
            ?.listener
            ?.onTitleChanged
            ?.call(call.arguments["title"] as String);
        return;
      case "allCookiesVisited":
        _handleVisitCookies(Map.from(call.arguments));
        return;
      case "urlCookiesVisited":
        _handleVisitCookies(Map.from(call.arguments));
        return;
      case 'javascriptChannelMessage':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onJavascriptChannelMessage?.call(
            call.arguments['channel'] as String,
            call.arguments['message'] as String,
            call.arguments['callbackId'] as String,
            call.arguments['frameId'] as String);
        return;
      case 'onFocusedNodeChangeMessage':
        int browserId = call.arguments['browserId'] as int;
        bool editable = call.arguments['editable'] as bool;
        _webViews[browserId]?.onFocusedNodeChangeMessage(editable);
        return;
      case 'onImeCompositionRangeChangedMessage':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onImeCompositionRangeChangedMessage?.call(
            call.arguments['x'] as double, call.arguments['y'] as double);
        return;
      default:
    }
  }

  Future<void> setCookie(String domain, String key, String val) async {
    assert(value);
    return _pluginChannel.invokeMethod('setCookie', [domain, key, val]);
  }

  Future<void> deleteCookie(String domain, String key) async {
    assert(value);
    return _pluginChannel.invokeMethod('deleteCookie', [domain, key]);
  }

  Future<void> visitAllCookies() async {
    assert(value);
    return _pluginChannel.invokeMethod('visitAllCookies');
  }

  Future<void> visitUrlCookies(String domain, bool isHttpOnly) async {
    assert(value);
    return _pluginChannel.invokeMethod('visitUrlCookies', [domain, isHttpOnly]);
  }
}
