import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'webview_events_listener.dart';
import 'webview_javascript.dart';
import 'webview_textinput.dart';

const MethodChannel _pluginChannel = MethodChannel("webview_cef");

class WebViewController extends ValueNotifier<bool> {
  late Completer<void> _creatingCompleter;

  Map<int, WebView> _webViews = <int, WebView>{}; // browserId -> WebView

  bool _isDisposed = false;
  WebviewEventsListener? _listener;
  bool _focusEditable = false;
  String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36";

  Future<void> get ready => _creatingCompleter.future;

  WebViewController() : super(false);

  void setUserAgent(String userAgent) {
    this.userAgent = userAgent;
  }

  /// Initializes the underlying platform view.
  Future<void> initialize() async {
    if (_isDisposed) {
      return Future<void>.value();
    }
    _creatingCompleter = Completer<void>();
    try {
      value = true;
      await _pluginChannel.invokeMethod('init', userAgent);
      _pluginChannel.setMethodCallHandler(_methodCallhandler);
      _creatingCompleter.complete();
    } on PlatformException catch (e) {
      _creatingCompleter.completeError(e);
    }

    return _creatingCompleter.future;
  }

  Future<void> _methodCallhandler(MethodCall call) async {
    if (_listener == null) return;
    switch (call.method) {
      case "urlChanged":
        _listener?.onUrlChanged?.call(call.arguments);
        return;
      case "titleChanged":
        _listener?.onTitleChanged?.call(call.arguments);
        return;
      case "allCookiesVisited":
        _listener?.onAllCookiesVisited?.call(Map.from(call.arguments));
        return;
      case "urlCookiesVisited":
        _listener?.onUrlCookiesVisited?.call(Map.from(call.arguments));
        return;
      case 'javascriptChannelMessage':
        _handleJavascriptChannelMessage(
            call.arguments['channel'],
            call.arguments['message'],
            call.arguments['callbackId'],
            call.arguments['browserId'],
            call.arguments['frameId']);
        return;
      case 'onFocusedNodeChangeMessage':
        _onFocusedNodeChangeMessage?.call(call.arguments as bool);
        return;
      case 'onImeCompositionRangeChangedMessage':
        _onImeCompositionRangeChangedMessage?.call(
            (call.arguments['x'] as int).toDouble(),
            (call.arguments['y'] as int).toDouble());
        return;
      default:
    }
  }

  setWebviewListener(WebviewEventsListener listener) {
    _listener = listener;
  }

  @override
  Future<void> dispose() async {
    await _creatingCompleter.future;
    if (!_isDisposed) {
      _isDisposed = true;
      await _pluginChannel.invokeMethod('dispose');
    }
    super.dispose();
  }

  WebView createWebView() {
    final browserId = _webViews.length + 1;
    final webView = WebView(this, browserId);
    _webViews[browserId] = webView;
    return webView;
  }

  Future<void> create(browserId) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    _webViews[browserId]!._textureId =
        await _pluginChannel.invokeMethod<int>('create', browserId) as int;
  }

  /// Loads the given [url].
  Future<void> loadUrl(int browserId, String url) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('loadUrl', [browserId, url]);
  }

  /// Reloads the current document.
  Future<void> reload(int browserId) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('reload', browserId);
  }

  Future<void> goForward(int browserId) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('goForward', browserId);
  }

  Future<void> goBack(int browserId) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('goBack', browserId);
  }

  Future<void> openDevTools(int browserId) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('openDevTools', browserId);
  }

  Future<void> imeSetComposition(String composingText) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('imeSetComposition', composingText);
  }

  Future<void> imeCommitText(String composingText) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('imeCommitText', composingText);
  }

  Future<void> setClientFocus(bool focus) {
    return _pluginChannel.invokeMethod('setClientFocus', [focus]);
  }

  Future<void> setCookie(String domain, String key, String val) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('setCookie', [domain, key, val]);
  }

  Future<void> deleteCookie(String domain, String key) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('deleteCookie', [domain, key]);
  }

  Future<void> visitAllCookies() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('visitAllCookies');
  }

  Future<void> visitUrlCookies(String domain, bool isHttpOnly) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('visitUrlCookies', [domain, isHttpOnly]);
  }

  Future<void> setJavaScriptChannels(
      int browserId, Set<JavascriptChannel> channels) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    _assertJavascriptChannelNamesAreUnique(channels);

    channels.forEach((channel) {
      _webViews[browserId]!._javascriptChannels[channel.name] = channel;
    });

    return _pluginChannel.invokeMethod('setJavaScriptChannels',
        [browserId, _extractJavascriptChannelNames(channels).toList()]);
  }

  Future<void> sendJavaScriptChannelCallBack(bool error, String result,
      String callbackId, int browserId, String frameId) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('sendJavaScriptChannelCallBack',
        [error, result, callbackId, browserId, frameId]);
  }

  Future<void> executeJavaScript(int browserId, String code) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('executeJavaScript', [browserId, code]);
  }

  /// Moves the virtual cursor to [position].
  Future<void> _cursorMove(int browserId, Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod(
        'cursorMove', [browserId, position.dx.round(), position.dy.round()]);
  }

  Future<void> _cursorDragging(int browserId, Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('cursorDragging',
        [browserId, position.dx.round(), position.dy.round()]);
  }

  Future<void> _cursorClickDown(int browserId, Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('cursorClickDown',
        [browserId, position.dx.round(), position.dy.round()]);
  }

  Future<void> _cursorClickUp(int browserId, Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod(
        'cursorClickUp', [browserId, position.dx.round(), position.dy.round()]);
  }

  /// Sets the horizontal and vertical scroll delta.
  Future<void> _setScrollDelta(
      int browserId, Offset position, int dx, int dy) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('setScrollDelta',
        [browserId, position.dx.round(), position.dy.round(), dx, dy]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setSize(int browserId, double dpi, Size size) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel
        .invokeMethod('setSize', [browserId, dpi, size.width, size.height]);
  }

  Set<String> _extractJavascriptChannelNames(Set<JavascriptChannel> channels) {
    final Set<String> channelNames =
        channels.map((JavascriptChannel channel) => channel.name).toSet();
    return channelNames;
  }

  void _handleJavascriptChannelMessage(
      final String channelName,
      final String message,
      final String callbackId,
      final int browserId,
      final String frameId) {
    if (_webViews[browserId] != null &&
        _webViews[browserId]!._javascriptChannels.containsKey(channelName)) {
      _webViews[browserId]!
          ._javascriptChannels[channelName]!
          .onMessageReceived(JavascriptMessage(message, callbackId, frameId));
    } else {
      print('Channel "$channelName" is not exstis');
    }
  }

  void _assertJavascriptChannelNamesAreUnique(
      final Set<JavascriptChannel>? channels) {
    if (channels == null || channels.isEmpty) {
      return;
    }
    assert(_extractJavascriptChannelNames(channels).length == channels.length);
  }

  Function(bool)? _onFocusedNodeChangeMessage;

  Function(double, double)? _onImeCompositionRangeChangedMessage;
}

class WebView extends StatefulWidget {
  final WebViewController controller;
  final _browserId;

  WebView(this.controller, this._browserId, {Key? key}) : super(key: key);

  int _textureId = 0;
  int get BrowserId => _browserId;

  final Map<String, JavascriptChannel> _javascriptChannels =
      <String, JavascriptChannel>{};

  @override
  WebViewState createState() => WebViewState();
}

class WebViewState extends State<WebView> with WebeViewTextInput {
  final GlobalKey _key = GlobalKey();
  String _composingText = '';
  late final _focusNode = FocusNode();
  bool isPrimaryFocus = false;

  WebViewController get _controller => widget.controller;

  @override
  updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    /// Handles IME composition only
    for (var d in textEditingDeltas) {
      if (d is TextEditingDeltaInsertion) {
        // composing text
        if (d.composing.isValid) {
          _composingText += d.textInserted;
          _controller.imeSetComposition(_composingText);
        } else if (!Platform.isWindows) {
          _controller.imeCommitText(d.textInserted);
        }
      } else if (d is TextEditingDeltaDeletion) {
        if (d.composing.isValid) {
          if (_composingText == d.textDeleted) {
            _composingText = "";
          }
          _controller.imeSetComposition(_composingText);
        }
      } else if (d is TextEditingDeltaReplacement) {
        if (d.composing.isValid) {
          _composingText = d.replacementText;
          _controller.imeSetComposition(_composingText);
        }
      } else if (d is TextEditingDeltaNonTextUpdate) {
        if (_composingText.isNotEmpty) {
          _controller.imeCommitText(_composingText);
          _composingText = '';
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.create(widget._browserId);
    _controller._onFocusedNodeChangeMessage = (editable) {
      _composingText = '';
      editable ? attachTextInputClient() : detachTextInputClient();
      _controller._focusEditable = editable;
    };

    _controller._onImeCompositionRangeChangedMessage = (x, y) {
      final box = _key.currentContext!.findRenderObject() as RenderBox;
      updateIMEComposionPosition(x, y, box.localToGlobal(Offset.zero));
    };

    // Report initial surface size
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reportSurfaceSize(context));
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      canRequestFocus: true,
      debugLabel: "webview_cef",
      onFocusChange: (focused) {
        _composingText = '';
        if (focused) {
          _controller.setClientFocus(true);
          if (_controller._focusEditable) {
            attachTextInputClient();
          }
        } else {
          _controller.setClientFocus(false);
          if (_controller._focusEditable) {
            detachTextInputClient();
          }
        }
      },
      child: SizedBox.expand(key: _key, child: _buildInner()),
    );
  }

  Widget _buildInner() {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        _reportSurfaceSize(context);
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Listener(
          onPointerHover: (ev) {
            _controller._cursorMove(widget._browserId, ev.localPosition);
          },
          onPointerDown: (ev) {
            if (!_focusNode.hasFocus) {
              _controller._onImeCompositionRangeChangedMessage?.call(0, 0);
              _focusNode.requestFocus();
              Future.delayed(const Duration(milliseconds: 50), () {
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
              });
            }
            _controller._cursorClickDown(widget._browserId, ev.localPosition);
          },
          onPointerUp: (ev) {
            _controller._cursorClickUp(widget._browserId, ev.localPosition);
          },
          onPointerMove: (ev) {
            _controller._cursorDragging(widget._browserId, ev.localPosition);
          },
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _controller._setScrollDelta(
                  widget._browserId,
                  signal.localPosition,
                  signal.scrollDelta.dx.round(),
                  signal.scrollDelta.dy.round());
            }
          },
          onPointerPanZoomUpdate: (event) {
            _controller._setScrollDelta(widget._browserId, event.localPosition,
                event.panDelta.dx.round(), event.panDelta.dy.round());
          },
          child: Texture(textureId: widget._textureId),
        ),
      ),
    );
  }

  void _reportSurfaceSize(BuildContext context) async {
    double dpi = MediaQuery.of(context).devicePixelRatio;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      await _controller.ready;
      unawaited(_controller._setSize(
          widget._browserId, dpi, Size(box.size.width, box.size.height)));
    }
  }
}
