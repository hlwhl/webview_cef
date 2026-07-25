import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  late WebViewController _controller;
  final _textController = TextEditingController();
  String title = "";
  Map allCookies = {};

  // Progress bar
  late AnimationController _progressAnimController;
  double _progress = 0;
  bool _showProgress = false;

  @override
  void initState() {
    var injectUserScripts = InjectUserScripts();
    injectUserScripts.add(UserScript("console.log('injectScript_in_LoadStart')",
        ScriptInjectTime.LOAD_START));
    injectUserScripts.add(UserScript(
        "console.log('injectScript_in_LoadEnd')", ScriptInjectTime.LOAD_END));

    // CSS Injection Script Example
    // injectUserScripts.add(UserScript(
    //   '''
    //     const style = document.createElement('style');
    //     style.innerHTML = `
    //       body {
    //         background-color: yellow;
    //       }
    //     `;
    //
    //     document.head.appendChild(style);
    //   ''',
    //   ScriptInjectTime.LOAD_END,
    // ));

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnimController.addListener(() {
      setState(() {
        _progress = _progressAnimController.value;
      });
    });

    _controller = WebviewManager().createWebView(
        loading: const Text("not initialized"),
        injectUserScripts: injectUserScripts);
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
    _controller.dispose();
    WebviewManager().quit();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    await WebviewManager().initialize(userAgent: "test/userAgent");
    String url = "www.baidu.com";
    _textController.text = url;
    //unified interface for all platforms set user agent
    _controller.setWebviewListener(WebViewEventsListener(
      onPageStarted: (controller, url) {
        debugPrint("onPageStarted => $url");
        _progress = 0;
        _showProgress = true;
        _progressAnimController.forward(from: 0);
      },
      onPageFinished: (controller, url) {
        debugPrint("onPageFinished => $url");
        controller.getTitle().then((t) {
          if (t != null && mounted) {
            setState(() => title = t);
          }
        });
        _progressAnimController.forward(from: 0).then((_) {
          if (mounted) {
            setState(() {
              _showProgress = false;
              _progress = 0;
            });
          }
        });
      },
      onNavigateRequest: (controller, url) {
        debugPrint("onNavigateRequest => $url");
        // Example: block navigation to certain domains
        if (url.contains('spam.com')) {
          debugPrint("Navigation to '$url' blocked.");
          controller.stopLoading();
          return NavigationPolicy.cancel;
        }
        return NavigationPolicy.allow;
      },
      onProgressUpdated: (controller, progress) {
        debugPrint("onProgressUpdated => ${(progress * 100).toStringAsFixed(0)}%");
        // Update a progress indicator with the 0.0-1.0 value.
        _progressAnimController.value = progress;
      },
      onPageFailed: (controller, url, error) {
        debugPrint(
            "onPageFailed => url: $url, code: ${error.code}, "
            "message: ${error.message}");
        // Hide progress on error.
        _showProgress = false;
        _progress = 0;
      },
    ));

    await _controller.initialize(_textController.text);

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void _loadLocalHtml() {
    final file = File(
      '${Directory.current.path}'
      '${Platform.pathSeparator}..'
      '${Platform.pathSeparator}web-playground'
      '${Platform.pathSeparator}bridge.html',
    ).absolute;
    final fileUrl = file.uri.toString();
    _controller.loadUrl(fileUrl);
    _textController.text = fileUrl;
  }

  void _showInfoAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withAlpha(230),
          title: const Text('Title'),
          content: const Text('Message'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
          body: Column(
        children: [
          SizedBox(
            height: 20,
            child: Text(title),
          ),
          Row(
            children: [
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: () {
                    _controller.reload();
                  },
                  child: const Icon(Icons.refresh),
                ),
              ),
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      _controller.goBack();
                    }
                  },
                  child: const Icon(Icons.arrow_left),
                ),
              ),
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: () async {
                    if (await _controller.canGoForward()) {
                      _controller.goForward();
                    }
                  },
                  child: const Icon(Icons.arrow_right),
                ),
              ),
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: () {
                    _controller.openDevTools();
                  },
                  child: const Icon(Icons.developer_mode),
                ),
              ),
              Builder(
                builder: (scaffoldContext) => SizedBox(
                  height: 48,
                  child: MaterialButton(
                    onPressed: () {
                      _showInfoAlert(scaffoldContext);
                    },
                    child: const Icon(Icons.info_outline),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: _loadLocalHtml,
                  child: const Icon(Icons.file_open),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: (url) {
                    _controller.loadUrl(url);
                    WebviewManager().visitAllCookies().then((value) {
                      allCookies = Map.of(value);
                      if (url == "baidu.com") {
                        if (!allCookies.containsKey('.$url') ||
                            !Map.of(allCookies['.$url']).containsKey('test')) {
                          WebviewManager().setCookie(url, 'test', 'test123');
                        } else {
                          WebviewManager().deleteCookie(url, 'test');
                        }
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          Expanded(
              child: Stack(
            children: [
              Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      return _controller.value
                          ? Expanded(child: _controller.webviewWidget)
                          : _controller.loadingWidget;
                    },
                  ),
                ],
              ),
              // Progress bar overlay on z-axis above the WebView
              if (_showProgress)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.blueAccent),
                    ),
                  ),
                ),
            ],
          ))
        ],
      )),
    );
  }
}
