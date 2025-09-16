import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'webview_manager.dart';
import 'webview_events_listener.dart';
import 'webview_javascript.dart';
import 'webview_textinput.dart';
import 'webview_tooltip.dart';

class _ScrollEvent {
  final Offset pos;
  final int dx;
  final int dy;
  const _ScrollEvent(this.pos, this.dx, this.dy);
}

class WebViewController extends ValueNotifier<bool> {
  WebViewController(this._pluginChannel, this._index, {Widget? loading})
      : super(false) {
    _loadingWidget = loading;
  }
  final MethodChannel _pluginChannel;
  Widget? _loadingWidget;

  late WebView _webviewWidget;
  Widget get webviewWidget => _webviewWidget;
  Widget get loadingWidget => _loadingWidget ?? const Text("loading...");

  late Completer<void> _creatingCompleter;
  Future<void> get ready => _creatingCompleter.future;
  bool _isDisposed = false;
  bool _focusEditable = false;

  final int _index;
  late int _browserId;
  late int _textureId;
  final Map<String, JavascriptChannel> _javascriptChannels =
      <String, JavascriptChannel>{};
  Map<String, JavascriptChannel> get javascriptChannels => _javascriptChannels;
  WebviewEventsListener? _listener;
  WebviewEventsListener? get listener => _listener;

  void Function(String, String, String, String)?
      get onJavascriptChannelMessage => (
            final String channelName,
            final String message,
            final String callbackId,
            final String frameId,
          ) {
            if (_javascriptChannels.containsKey(channelName)) {
              _javascriptChannels[channelName]!.onMessageReceived(
                JavascriptMessage(message, callbackId, frameId),
              );
            } else {
              debugPrint('Channel "$channelName" is not exists');
            }
          };

  void Function(String)? get onToolTip => _onToolTip;
  void Function(int)? get onCursorChanged => _onCursorChanged;
  void Function(bool)? get onFocusedNodeChangeMessage =>
      _onFocusedNodeChangeMessage;
  void Function(int, int)? get onImeCompositionRangeChangedMessage =>
      _onImeCompositionRangeChangedMessage;

  /// Initializes the underlying platform view.
  Future<void> initialize(String url) async {
    if (_isDisposed) {
      return Future<void>.value();
    }
    _creatingCompleter = Completer<void>();
    try {
      await WebviewManager().ready;
      final List<dynamic> args =
          await _pluginChannel.invokeMethod('create', url);
      _browserId = args[0] as int;
      _textureId = args[1] as int;
      WebviewManager().onBrowserCreated(_index, _browserId);
      await Future.delayed(const Duration(milliseconds: 50));
      _webviewWidget = WebView(this);
      value = true;
      _creatingCompleter.complete();
    } on PlatformException catch (e) {
      _creatingCompleter.completeError(e);
    }
    return _creatingCompleter.future;
  }

  void setWebviewListener(WebviewEventsListener listener) {
    _listener = listener;
  }

  @override
  Future<void> dispose() async {
    await _creatingCompleter.future;
    if (!_isDisposed) {
      _isDisposed = true;
      WebviewManager().removeWebView(_browserId);
      await _pluginChannel.invokeMethod('close', _browserId);
    }
    super.dispose();
  }

  /// Loads the given [url].
  Future<void> loadUrl(String url) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('loadUrl', [_browserId, url]);
  }

  /// Reloads the current document.
  Future<void> reload() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('reload', _browserId);
  }

  Future<void> goForward() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('goForward', _browserId);
  }

  Future<void> goBack() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('goBack', _browserId);
  }

  Future<void> openDevTools() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('openDevTools', _browserId);
  }

  Future<void> imeSetComposition(String composingText) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('imeSetComposition', [
      _browserId,
      composingText,
    ]);
  }

  Future<void> imeCommitText(String composingText) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('imeCommitText', [
      _browserId,
      composingText,
    ]);
  }

  Future<void> setClientFocus(bool focus) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('setClientFocus', [_browserId, focus]);
  }

  Future<void> setJavaScriptChannels(Set<JavascriptChannel> channels) async {
    if (_isDisposed) {
      return;
    }
    await ready;
    _assertJavascriptChannelNamesAreUnique(channels);

    for (var channel in channels) {
      _javascriptChannels[channel.name] = channel;
    }

    return _pluginChannel.invokeMethod('setJavaScriptChannels', [
      _browserId,
      _extractJavascriptChannelNames(channels).toList(),
    ]);
  }

  Future<void> sendJavaScriptChannelCallBack(
    bool error,
    String result,
    String callbackId,
    String frameId,
  ) async {
    if (_isDisposed) {
      return;
    }
    await ready;
    return _pluginChannel.invokeMethod('sendJavaScriptChannelCallBack', [
      error,
      result,
      callbackId,
      _browserId,
      frameId,
    ]);
  }

  Future<void> executeJavaScript(String code) async {
    if (_isDisposed) {
      return;
    }
    await ready;
    return _pluginChannel.invokeMethod('executeJavaScript', [_browserId, code]);
  }

  Future<dynamic> evaluateJavascript(String code) async {
    if (_isDisposed) {
      return;
    }
    await ready;
    return _pluginChannel.invokeMethod('evaluateJavascript', [
      _browserId,
      code,
    ]);
  }

  /// Moves the virtual cursor to [position].
  Future<void> _cursorMove(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('cursorMove', [
      _browserId,
      position.dx.round(),
      position.dy.round(),
    ]);
  }

  Future<void> _cursorDragging(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('cursorDragging', [
      _browserId,
      position.dx.round(),
      position.dy.round(),
    ]);
  }

  Future<void> _cursorClickDown(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('cursorClickDown', [
      _browserId,
      position.dx.round(),
      position.dy.round(),
    ]);
  }

  Future<void> _cursorClickUp(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('cursorClickUp', [
      _browserId,
      position.dx.round(),
      position.dy.round(),
    ]);
  }

  /// Sets the horizontal and vertical scroll delta.
  Future<void> _setScrollDelta(Offset position, int dx, int dy) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('setScrollDelta', [
      _browserId,
      position.dx.round(),
      position.dy.round(),
      dx,
      dy,
    ]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setSize(double dpi, Size size) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _pluginChannel.invokeMethod('setSize', [
      _browserId,
      dpi,
      size.width,
      size.height,
    ]);
  }

  Set<String> _extractJavascriptChannelNames(Set<JavascriptChannel> channels) {
    final Set<String> channelNames =
        channels.map((JavascriptChannel channel) => channel.name).toSet();
    return channelNames;
  }

  void _assertJavascriptChannelNamesAreUnique(
    final Set<JavascriptChannel>? channels,
  ) {
    if (channels == null || channels.isEmpty) {
      return;
    }
    assert(_extractJavascriptChannelNames(channels).length == channels.length);
  }

  void Function(String)? _onToolTip;
  void Function(int)? _onCursorChanged;
  void Function(bool)? _onFocusedNodeChangeMessage;
  void Function(int, int)? _onImeCompositionRangeChangedMessage;
}

class WebView extends StatefulWidget {
  final WebViewController controller;

  const WebView(this.controller, {super.key});

  @override
  WebViewState createState() => WebViewState();
}

class WebViewState extends State<WebView> with WebeViewTextInput {
  final GlobalKey _key = GlobalKey();
  String _composingText = '';
  late final _focusNode = FocusNode();
  bool isPrimaryFocus = false;
  WebviewTooltip? _tooltip;
  MouseCursor _mouseType = SystemMouseCursors.basic;
  // Cache last reported surface parameters to avoid redundant platform calls.
  Size? _lastReportedSize;
  double? _lastReportedDpi;
  // Coalescing state for high-frequency input events.
  Offset? _lastHoverPos;
  Offset? _lastDragPos;
  _ScrollEvent? _lastScroll;
  bool _inputFlushScheduled = false;

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
    _controller._onFocusedNodeChangeMessage = (editable) {
      _composingText = '';
      editable ? attachTextInputClient() : detachTextInputClient();
      _controller._focusEditable = editable;
    };

    _controller._onImeCompositionRangeChangedMessage = (x, y) {
      final box = _key.currentContext!.findRenderObject() as RenderBox;
      updateIMEComposionPosition(
        x.toDouble(),
        y.toDouble(),
        box.localToGlobal(Offset.zero),
      );
    };

    _controller._onToolTip = (final String text) {
      _tooltip ??= WebviewTooltip(_key.currentContext!);
      _tooltip?.showToolTip(text);
    };

    _controller._onCursorChanged = (int type) {
      switch (type) {
        case 0:
          _mouseType = SystemMouseCursors.basic;
          break;
        case 1:
          _mouseType = SystemMouseCursors.precise;
          break;
        case 2:
          _mouseType = SystemMouseCursors.click;
          break;
        case 3:
          _mouseType = SystemMouseCursors.text;
          break;
        case 4:
          _mouseType = SystemMouseCursors.wait;
          break;
        default:
          _mouseType = SystemMouseCursors.basic;
          break;
      }
      setState(() {});
    };

    // Report initial surface size
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reportSurfaceSize(context),
    );
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
            _lastHoverPos = ev.localPosition;
            _scheduleInputFlush();
            _tooltip?.cursorOffset = ev.position;
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
            _controller._cursorClickDown(ev.localPosition);
          },
          onPointerUp: (ev) {
            _controller._cursorClickUp(ev.localPosition);
          },
          onPointerMove: (ev) {
            _lastDragPos = ev.localPosition;
            _scheduleInputFlush();
          },
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _lastScroll = _ScrollEvent(
                signal.localPosition,
                signal.scrollDelta.dx.round(),
                signal.scrollDelta.dy.round(),
              );
              _scheduleInputFlush();
            }
          },
          onPointerPanZoomUpdate: (event) {
            _lastScroll = _ScrollEvent(
              event.localPosition,
              event.panDelta.dx.round(),
              event.panDelta.dy.round(),
            );
            _scheduleInputFlush();
          },
          child: MouseRegion(
            cursor: _mouseType,
            child: Texture(textureId: _controller._textureId),
          ),
        ),
      ),
    );
  }

  void _reportSurfaceSize(BuildContext context) async {
    double dpi = MediaQuery.of(context).devicePixelRatio;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      await _controller.ready;
      final Size sz = Size(box.size.width, box.size.height);
      // Only notify platform when size or dpi actually changed.
      if (_lastReportedSize != sz || _lastReportedDpi != dpi) {
        _lastReportedSize = sz;
        _lastReportedDpi = dpi;
        unawaited(_controller._setSize(dpi, sz));
      }
    }
  }

  void _scheduleInputFlush() {
    if (_inputFlushScheduled) return;
    _inputFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFlushScheduled = false;
      // Drain latest hover
      final hover = _lastHoverPos;
      if (hover != null) {
        _lastHoverPos = null;
        _controller._cursorMove(hover);
      }
      // Drain latest drag
      final drag = _lastDragPos;
      if (drag != null) {
        _lastDragPos = null;
        _controller._cursorDragging(drag);
      }
      // Drain latest scroll
      final scroll = _lastScroll;
      if (scroll != null) {
        _lastScroll = null;
        _controller._setScrollDelta(scroll.pos, scroll.dx, scroll.dy);
      }
    });
  }
}
