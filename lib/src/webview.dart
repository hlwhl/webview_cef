import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'webview_events_listener.dart';

const MethodChannel _pluginChannel = MethodChannel("webview_cef");
bool _hasCallStartCEF = false;
final _cefStarted = Completer();

_startCEF() async {
  if (!_hasCallStartCEF) {
    _hasCallStartCEF = true;
    _pluginChannel.invokeMethod("startCEF");
    _pluginChannel.setMethodCallHandler((call) async {
      if (call.method == 'onCEFInitialized') {
        _cefStarted.complete();
      }
    });
  }

  await _cefStarted.future;
}

const _kEventTitleChanged = "titleChanged";
const _kEventURLChanged = "urlChanged";

class WebViewController extends ValueNotifier<bool> {
  static int _id = 0;

  final Completer<void> _creatingCompleter = Completer<void>();
  int _textureId = 0;
  bool _isDisposed = false;
  WebviewEventsListener? _listener;
  late final MethodChannel _broswerChannel;
  late final EventChannel _eventChannel;
  StreamSubscription? _eventStreamSubscription;

  Future<void> get ready => _creatingCompleter.future;

  WebViewController() : super(false);

  /// Initializes the underlying platform view.
  Future<void> initialize() async {
    if (_isDisposed) {
      return Future<void>.value();
    }

    await _startCEF();

    try {
      final browserID = ++_id;
      _broswerChannel = MethodChannel('webview_cef/$browserID');
      _broswerChannel.setMethodCallHandler(_methodCallhandler);
      _textureId = await _pluginChannel.invokeMethod<int>('createBrowser', browserID) ?? 0;
      _eventChannel = EventChannel('webview_cef/$browserID/events');
      _eventStreamSubscription = _eventChannel.receiveBroadcastStream().listen(_handleBrowserEvents);
    } on PlatformException catch (e) {
      _creatingCompleter.completeError(e);
    }

    return _creatingCompleter.future;
  }

  Future<dynamic> _methodCallhandler(MethodCall call) async {
    switch (call.method) {
      case 'onBrowserCreated':
        _creatingCompleter.complete();
        value = true;
        return null;
    }

    return null;
  }

  _handleBrowserEvents(dynamic event) {
    final m = event as Map<dynamic, dynamic>;
    switch (m['type']) {
      case _kEventURLChanged:
        _listener?.onUrlChanged?.call(m['value'] as String);
        return;
      case _kEventTitleChanged:
        _listener?.onTitleChanged?.call(m['value'] as String);
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
      await _broswerChannel.invokeMethod('dispose');
      _eventStreamSubscription?.cancel();
    }
    super.dispose();
  }

  /// Loads the given [url].
  Future<void> loadUrl(String url) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod('loadUrl', url);
  }

  /// Reloads the current document.
  Future<void> reload() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod('reload');
  }

  Future<void> goForward() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod('goForward');
  }

  Future<void> goBack() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod('goBack');
  }

  Future<void> openDevTools() async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod('openDevTools');
  }

  /// Moves the virtual cursor to [position].
  Future<void> _cursorMove(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel
        .invokeMethod('cursorMove', [position.dx.round(), position.dy.round()]);
  }

  Future<void> _cursorDragging(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod(
        'cursorDragging', [position.dx.round(), position.dy.round()]);
  }

  Future<void> _cursorClickDown(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod(
        'cursorClickDown', [position.dx.round(), position.dy.round()]);
  }

  Future<void> _cursorClickUp(Offset position) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod(
        'cursorClickUp', [position.dx.round(), position.dy.round()]);
  }

  /// Sets the horizontal and vertical scroll delta.
  Future<void> _setScrollDelta(Offset position, int dx, int dy) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel.invokeMethod(
        'setScrollDelta', [position.dx.round(), position.dy.round(), dx, dy]);
  }

  /// Sets the surface size to the provided [size].
  Future<void> _setSize(double dpi, Size size) async {
    if (_isDisposed) {
      return;
    }
    assert(value);
    return _broswerChannel
        .invokeMethod('setSize', [dpi, size.width, size.height]);
  }
}

class WebView extends StatefulWidget {
  final WebViewController controller;

  const WebView(this.controller, {Key? key}) : super(key: key);

  @override
  WebViewState createState() => WebViewState();
}

class WebViewState extends State<WebView> {
  final GlobalKey _key = GlobalKey();

  WebViewController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Report initial surface size
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reportSurfaceSize(context));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(key: _key, child: _buildInner());
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
            _controller._cursorMove(ev.localPosition);
          },
          onPointerDown: (ev) {
            _controller._cursorClickDown(ev.localPosition);
          },
          onPointerUp: (ev) {
            _controller._cursorClickUp(ev.localPosition);
          },
          onPointerMove: (ev) {
            _controller._cursorDragging(ev.localPosition);
          },
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _controller._setScrollDelta(signal.localPosition,
                  signal.scrollDelta.dx.round(), signal.scrollDelta.dy.round());
            }
          },
          onPointerPanZoomUpdate: (event) {
            _controller._setScrollDelta(event.localPosition,
                event.panDelta.dx.round(), event.panDelta.dy.round());
          },
          child: Texture(textureId: _controller._textureId),
        )));
  }

  void _reportSurfaceSize(BuildContext context) async {
    double dpi = MediaQuery.of(context).devicePixelRatio;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      await _controller.ready;
      unawaited(
          _controller._setSize(dpi, Size(box.size.width, box.size.height)));
    }
  }
}
