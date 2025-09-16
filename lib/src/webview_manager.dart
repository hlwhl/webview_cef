import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_cef/src/webview_inject_user_script.dart';

import 'webview.dart';

/// Singleton manager that initializes CEF and coordinates WebView instances.
class WebviewManager extends ValueNotifier<bool> {
  static final WebviewManager _instance = WebviewManager._internal();

  factory WebviewManager() => _instance;

  // Tracks the current initialization operation; null when not started yet.
  Completer<void>? _creatingCompleter;

  final MethodChannel pluginChannel = const MethodChannel("webview_cef");

  final Map<int, WebViewController> _webViews = <int, WebViewController>{};
  final Map<int, InjectUserScripts?> _injectUserScripts =
      <int, InjectUserScripts>{};

  final Map<int, WebViewController> _tempWebViews = <int, WebViewController>{};
  final Map<int, InjectUserScripts?> _tempInjectUserScripts =
      <int, InjectUserScripts>{};

  int nextIndex = 1;

  Future<void> get ready => _creatingCompleter?.future ?? Future.value();

  /// Create a WebView and return its controller.
  ///
  /// - [loading]: Placeholder shown until the native view is ready.
  /// - [injectUserScripts]: Scripts to inject automatically on LOAD_START/LOAD_END.
  WebViewController createWebView({
    Widget? loading,
    InjectUserScripts? injectUserScripts,
  }) {
    int browserIndex = nextIndex++;
    final controller = WebViewController(
      pluginChannel,
      browserIndex,
      loading: loading,
    );
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

  /// Initialize the native CEF runtime (idempotent).
  ///
  /// Parameters:
  /// - [userAgent]: Optional product string appended to the default UA.
  /// - [cachePath]: Directory for the global browser cache. If empty, runs in
  ///   memory (incognito-like) and no data is persisted to disk. Must be writable.
  /// - [persistSessionCookies]: Persist session cookies to disk. Effective only
  ///   when [cachePath] is non-empty.
  /// - [persistUserPreferences]: Persist user preferences (JSON) in [cachePath].
  ///   Effective only when [cachePath] is non-empty.
  /// - [enableGPU]: Enable GPU acceleration (true/false).
  Future<void> initialize({
    String? userAgent,
    String? cachePath,
    bool persistSessionCookies = false,
    bool persistUserPreferences = false,
    bool enableGPU = false,
    Duration initTimeout = const Duration(seconds: 5),
  }) async {
    // Idempotent: if already initialized, return immediately.
    if (value) {
      return Future.value();
    }
    // Re-entrant: if an initialization is in-flight, await the same future.
    if (_creatingCompleter?.isCompleted == false) {
      return _creatingCompleter!.future;
    }
    _creatingCompleter = Completer<void>();
    try {
      // Build init options map; keep legacy behavior if only userAgent provided
      final hasAnyOption = (userAgent != null && userAgent.isNotEmpty) ||
          (cachePath != null && cachePath.isNotEmpty) ||
          persistSessionCookies ||
          persistUserPreferences ||
          enableGPU;

      if (hasAnyOption) {
        final Map<String, dynamic> opts = {};
        if (userAgent != null && userAgent.isNotEmpty) {
          opts['userAgent'] = userAgent;
        }
        if (cachePath != null && cachePath.isNotEmpty) {
          opts['cachePath'] = cachePath;
        }
        if (persistSessionCookies) opts['persistSessionCookies'] = true;
        if (persistUserPreferences) opts['persistUserPreferences'] = true;
        if (enableGPU) opts['enableGPU'] = true;
        await pluginChannel.invokeMethod('init', opts).timeout(initTimeout,
            onTimeout: () {
          throw PlatformException(
            code: 'INIT_TIMEOUT',
            message:
                'webview_cef init did not respond. Verify CEF binaries and plugin initialization on the platform side.',
          );
        });
      } else {
        await pluginChannel.invokeMethod('init').timeout(initTimeout,
            onTimeout: () {
          throw PlatformException(
            code: 'INIT_TIMEOUT',
            message:
                'webview_cef init did not respond. Verify CEF binaries and plugin initialization on the platform side.',
          );
        });
      }
      pluginChannel.setMethodCallHandler(methodCallhandler);
      // Wait for the platform to complete initialization.
      await Future.delayed(const Duration(milliseconds: 300));
      _creatingCompleter?.complete();
      value = true;
    } on PlatformException catch (e) {
      _creatingCompleter?.completeError(e);
    }
    return _creatingCompleter?.future;
  }

  @override
  void dispose() {
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
      case "urlChanged":
        int browserId = call.arguments["browserId"] as int;
        _webViews[browserId]?.listener?.onUrlChanged?.call(
              call.arguments["url"] as String,
            );
        return;
      case "titleChanged":
        int browserId = call.arguments["browserId"] as int;
        _webViews[browserId]?.listener?.onTitleChanged?.call(
              call.arguments["title"] as String,
            );
        return;
      case "onConsoleMessage":
        int browserId = call.arguments["browserId"] as int;
        _webViews[browserId]?.listener?.onConsoleMessage?.call(
              call.arguments["level"] as int,
              call.arguments["message"] as String,
              call.arguments["source"] as String,
              call.arguments["line"] as int,
            );
        return;
      case 'javascriptChannelMessage':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onJavascriptChannelMessage?.call(
              call.arguments['channel'] as String,
              call.arguments['message'] as String,
              call.arguments['callbackId'] as String,
              call.arguments['frameId'] as String,
            );
        return;
      case 'onTooltip':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onToolTip?.call(call.arguments['text'] as String);
        return;
      case 'onCursorChanged':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onCursorChanged?.call(
              call.arguments['type'] as int,
            );
        return;
      case 'onFocusedNodeChangeMessage':
        int browserId = call.arguments['browserId'] as int;
        bool editable = call.arguments['editable'] as bool;
        _webViews[browserId]?.onFocusedNodeChangeMessage?.call(editable);
        return;
      case 'onImeCompositionRangeChangedMessage':
        int browserId = call.arguments['browserId'] as int;
        _webViews[browserId]?.onImeCompositionRangeChangedMessage?.call(
              call.arguments['x'] as int,
              call.arguments['y'] as int,
            );
        return;
      case 'onLoadStart':
        int browserId = call.arguments["browserId"] as int;
        String urlId = call.arguments["urlId"] as String;

        await _injectUserScriptIfNeeds(
          browserId,
          _injectUserScripts[browserId]?.retrieveLoadStartInjectScripts() ?? [],
        );

        WebViewController controller =
            _webViews[browserId] as WebViewController;
        _webViews[browserId]?.listener?.onLoadStart?.call(controller, urlId);
        return;
      case 'onLoadEnd':
        int browserId = call.arguments["browserId"] as int;
        String urlId = call.arguments["urlId"] as String;

        await _injectUserScriptIfNeeds(
          browserId,
          _injectUserScripts[browserId]?.retrieveLoadEndInjectScripts() ?? [],
        );

        WebViewController controller =
            _webViews[browserId] as WebViewController;
        _webViews[browserId]?.listener?.onLoadEnd?.call(controller, urlId);
        return;
      default:
    }
  }

  Future<void> _injectUserScriptIfNeeds(
    int browserId,
    List<UserScript> scripts,
  ) async {
    if (scripts.isEmpty) return;
    final controller = _webViews[browserId];
    if (controller == null) return;
    await controller.ready;
    for (final script in scripts) {
      await controller.executeJavaScript(script.script);
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
    /// Visit cookies for the specified [domain].
    ///
    /// - [isHttpOnly]: If true, include HttpOnly cookies in the results.
    assert(value);
    return pluginChannel.invokeMethod('visitUrlCookies', [domain, isHttpOnly]);
  }

  Future<void> quit() async {
    /// Stop the global CEF runtime.
    ///
    /// Only call this when your app is exiting or you no longer need any webviews.
    assert(value);
    return pluginChannel.invokeMethod('quit');
  }
}
