import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_cef/src/webview_inject_user_script.dart';

import 'webview.dart';
import 'webview_events_listener.dart';

/// CEF process model.
///
/// Chromium runs web content in separate, sandboxed processes by default for
/// security and stability. Choose the model that fits your use case.
enum ProcessMode {
  /// Each unique site (eTLD+1) gets its own renderer process. Other processes
  /// (GPU, network, audio, etc.) remain separate. Strikes a balance between
  /// isolation and resource usage — typically **5–8 processes** total.
  ///
  /// Recommended for production apps that load arbitrary web content.
  processPerSite(1),

  /// Each browser tab gets its own renderer process. Maximises isolation at the
  /// cost of higher memory overhead when many tabs are open.
  processPerTab(2),

  /// Everything — browser, renderer, GPU, network — runs inside a single
  /// process. Minimal resource footprint (**~1 process**) but no sandbox
  /// isolation: a renderer crash kills the whole app.
  ///
  /// Best for:
  /// - embedded / kiosk apps that load known, trusted content
  /// - development and debugging (quick iteration with fewer processes)
  ///
  /// Avoid in production if loading untrusted third-party pages.
  singleProcess(3);

  final int value;

  const ProcessMode(this.value);
}

class WebviewManager extends ValueNotifier<bool> {
  static final WebviewManager _instance = WebviewManager._internal();

  factory WebviewManager() => _instance;

  late Completer<void> _creatingCompleter;

  final MethodChannel pluginChannel = const MethodChannel("webview_cef");

  final _webViews = <int, WebViewController>{};
  final _injectUserScripts = <int, InjectUserScripts?>{};

  final _tempWebViews = <int, WebViewController>{};
  final _tempInjectUserScripts = <int, InjectUserScripts?>{};

  int nextIndex = 1;

  bool? _hasNativeKeySupport;

  get ready => _creatingCompleter.future;

  /// Returns true if the platform has native key event handling (e.g., GTK on desktop Linux).
  /// When false, Dart-side key handling should be used (e.g., eLinux).
  Future<bool> get hasNativeKeySupport async {
    _hasNativeKeySupport ??= await pluginChannel.invokeMethod<bool>('hasNativeKeySupport') ?? false;
    return _hasNativeKeySupport!;
  }

  WebViewController createWebView({
    Widget? loading,
    InjectUserScripts? injectUserScripts,
  }) {
    int browserIndex = nextIndex++;
    final controller =
        WebViewController(pluginChannel, browserIndex, loading: loading);
    _tempWebViews[browserIndex] = controller;
    _tempInjectUserScripts[browserIndex] = injectUserScripts;

    return controller;
  }

  void removeWebView(int browserId) {
    if (browserId > 0) {
      _webViews.remove(browserId);
    }
  }

  WebviewManager._internal() : super(false);

  /// Initialize the CEF engine.
  ///
  /// Must be called once before creating any web views. Safe to call multiple
  /// times — subsequent calls are no-ops.
  ///
  /// [userAgent] overrides the default User-Agent string sent with HTTP
  /// requests.
  ///
  /// [processMode] controls the Chromium process model:
  /// - [ProcessMode.processPerSite] (default) — one renderer per unique site,
  ///   ~5–8 processes. Best for production with arbitrary web content.
  /// - [ProcessMode.processPerTab] — one renderer per tab, maximum isolation
  ///   but higher memory use.
  /// - [ProcessMode.singleProcess] — everything in one process (~1 process
  ///   total). Great for debugging, embedded/kiosk apps, or trusted content.
  ///   No sandbox — avoid with untrusted third-party pages.
  ///
  /// [cachePath] overrides the default CEF root cache directory. When omitted,
  /// each platform derives a unique default to prevent file-lock conflicts
  /// between multiple CEF-based apps running simultaneously:
  /// - macOS: `~/Library/Caches/<bundle_id>/cef`
  /// - Windows: `%LOCALAPPDATA%\<exe_name>\cef`
  /// - Linux / eLinux: `$XDG_CACHE_HOME/<exe_name>/cef`
  /// Set this only when your app needs the cache at a specific location.
  Future<void> initialize({
    String? userAgent,
    ProcessMode processMode = ProcessMode.processPerSite,
    String? cachePath,
  }) async {
    _creatingCompleter = Completer<void>();
    try {
      final args = <String, dynamic>{'processMode': processMode.value};
      if (userAgent != null && userAgent.isNotEmpty) {
        args['userAgent'] = userAgent;
      }
      if (cachePath != null && cachePath.isNotEmpty) {
        args['cachePath'] = cachePath;
      }
      await pluginChannel.invokeMethod('init', args);
      pluginChannel.setMethodCallHandler(methodCallhandler);
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
    pluginChannel.setMethodCallHandler(null);
    _webViews.clear();
  }

  void onBrowserCreated(int browserIndex, int browserId) {
    _webViews[browserId] = _tempWebViews[browserIndex]!;
    _injectUserScripts[browserId] = _tempInjectUserScripts[browserIndex];

    _tempWebViews.remove(browserIndex);
    _tempInjectUserScripts.remove(browserIndex);
  }

  Future<void> methodCallhandler(MethodCall call) async {
    switch (call.method) {
      case "onConsoleMessage":
        int browserId = call.arguments["browserId"] as int;
        _webViews[browserId]?.listener?.onConsoleMessage?.call(
            call.arguments["level"] as int,
            call.arguments["message"] as String,
            call.arguments["source"] as String,
            call.arguments["line"] as int);
        return;
      case 'javascriptChannelMessage':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onJavascriptChannelMessage?.call(
            call.arguments['channel'] as String,
            call.arguments['message'] as String,
            call.arguments['callbackId'] as String,
            call.arguments['frameId'] as String);
        return;
      case 'onTooltip':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onToolTip?.call(call.arguments['text'] as String);
        return;
      case 'onCursorChanged':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]
            ?.onCursorChanged
            ?.call(call.arguments['type'] as int);
        return;
      case 'onFocusedNodeChangeMessage':
        int browserId = call.arguments['browserId'] as int;
        bool editable = call.arguments['editable'] as bool;
        _webViews[browserId]?.onFocusedNodeChangeMessage(editable);
        return;
      case 'onImeCompositionRangeChangedMessage':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onImeCompositionRangeChangedMessage?.call(
            call.arguments['x'] as int,
            call.arguments['y'] as int,
            call.arguments['height'] as int);
        return;
      case 'onLoadStart':
        int browserId = call.arguments["browserId"] as int;
        String urlId = call.arguments["urlId"] as String;

        // Clear any visible tooltip when navigating away from the current
        // page — CEF does not guarantee an empty OnTooltip() before the
        // old page is destroyed.
        _webViews[browserId]?.onToolTip?.call('');

        final controller = _webViews[browserId];
        if (controller == null) return;
        await controller.ready;

        await _injectUserScriptIfNeeds(browserId, _injectUserScripts[browserId]?.retrieveLoadStartInjectScripts() ?? []);

        controller.listener?.onPageStarted?.call(controller, urlId);
        return;
      case 'onLoadEnd':
        int browserId = call.arguments["browserId"] as int;
        String urlId = call.arguments["urlId"] as String;

        final controller = _webViews[browserId];
        if (controller == null) return;
        await controller.ready;

        await _injectUserScriptIfNeeds(browserId, _injectUserScripts[browserId]?.retrieveLoadEndInjectScripts() ?? []);

        controller.listener?.onPageFinished?.call(controller, urlId);
        return;
      case 'onBeforeBrowse':
        int browserId = call.arguments['browserId'] as int;
        String url = call.arguments['url'] as String;
        final controller = _webViews[browserId];
        if (controller == null) return;

        await controller.ready;
        controller.listener?.onNavigateRequest?.call(controller, url);
        return;
      case 'onLoadingProgressChange':
        int browserId = call.arguments['browserId'] as int;
        double progress = (call.arguments['progress'] as num).toDouble();
        final controller = _webViews[browserId];
        if (controller == null) return;

        await controller.ready;
        controller.listener?.onProgressUpdated?.call(controller, progress);
        return;
      case 'onRenderProcessTerminated':
        int browserId = call.arguments['browserId'] as int;
        int status = call.arguments['status'] as int;
        int errorCode = call.arguments['errorCode'] as int;
        String errorString = call.arguments['errorString'] as String;
        final renderController = _webViews[browserId];
        if (renderController == null) return;

        await renderController.ready;
        renderController.listener?.onRenderProcessTerminated
            ?.call(renderController, status, errorCode, errorString);
        return;
      case 'onLoadError':
        int browserId = call.arguments['browserId'] as int;
        String errorUrl = call.arguments['url'] as String;
        int errorCode = call.arguments['errorCode'] as int;
        String errorText = call.arguments['errorText'] as String;
        final controller = _webViews[browserId];
        if (controller == null) return;

        await controller.ready;
        final error = WebViewError(errorCode, errorText, {'url': errorUrl});
        controller.listener?.onPageFailed?.call(controller, errorUrl, error);
        return;
      default:
    }
  }

  Future<void> _injectUserScriptIfNeeds(int browserId, List<UserScript> scripts) async {
    if (scripts.isEmpty) return;

    await _webViews[browserId]?.ready;

    for (final script in scripts) {
      await _webViews[browserId]?.executeJavaScript(script.script);
    }
  }

  Future<void> setCookie(String domain, String key, String val) async {
    assert(value);
    return pluginChannel.invokeMethod('setCookie', [domain, key, val]);
  }

  Future<void> deleteCookie(String domain, String key) async {
    assert(value);
    return pluginChannel.invokeMethod('deleteCookie', [domain, key]);
  }

  Future<dynamic> visitAllCookies() async {
    assert(value);
    return pluginChannel.invokeMethod('visitAllCookies');
  }

  Future<dynamic> visitUrlCookies(String domain, bool isHttpOnly) async {
    assert(value);
    return pluginChannel.invokeMethod('visitUrlCookies', [domain, isHttpOnly]);
  }

  Future<void> quit() async {
    //only call this method when you want to quit the app
    assert(value);
    return pluginChannel.invokeMethod('quit');
  }
}
