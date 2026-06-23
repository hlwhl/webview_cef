import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';
import 'package:webview_cef/src/webview_inject_user_script.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final bool useTabs = true; // Toggle this to switch modes

  // Single view mode
  late WebViewController _controller;
  final _textController = TextEditingController();
  String title = "";
  Map allCookies = {};

  // Tabbed view mode
  final List<WebViewController> _controllers = [];
  final List<String> _tabUrls = [];
  final _tabTextController = TextEditingController();
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    if (useTabs) {
      initTabbedMode();
    } else {
      initSingleMode();
    }
  }

  void initSingleMode() {
    var injectUserScripts = InjectUserScripts();
    injectUserScripts.add(UserScript("console.log('injectScript_in_LoadStart')",
        ScriptInjectTime.LOAD_START));
    injectUserScripts.add(UserScript(
        "console.log('injectScript_in_LoadEnd')", ScriptInjectTime.LOAD_END));

    _controller = WebviewManager().createWebView(
        loading: const Text("not initialized"),
        injectUserScripts: injectUserScripts);
    initPlatformState();
  }

  void initTabbedMode() {
    initPlatformState();
  }

  @override
  void dispose() {
    if (useTabs) {
      for (var c in _controllers) {
        c.dispose();
      }
    } else {
      _controller.dispose();
    }
    WebviewManager().quit();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    await WebviewManager().initialize(userAgent: "test/userAgent");

    if (useTabs) {
      _addNewTab("https://www.google.com");
      _addNewTab("https://flutter.dev");
    } else {
      String url = "www.google.com";
      _textController.text = url;
      //unified interface for all platforms set user agent
      _controller.setWebviewListener(WebviewEventsListener(
        onTitleChanged: (t) {
          setState(() {
            title = t;
          });
        },
        onUrlChanged: (url) {
          _textController.text = url;
          final Set<JavascriptChannel> jsChannels = {
            JavascriptChannel(
                name: 'Print',
                onMessageReceived: (JavascriptMessage message) {
                  print(message.message);
                  _controller.sendJavaScriptChannelCallBack(
                      false,
                      "{'code':'200','message':'print succeed!'}",
                      message.callbackId,
                      message.frameId);
                }),
          };
          //normal JavaScriptChannels
          _controller.setJavaScriptChannels(jsChannels);
          //also you can build your own jssdk by execute JavaScript code to CEF
          _controller.executeJavaScript("function abc(e){return 'abc:'+ e}");
          _controller
              .evaluateJavascript("abc('test')")
              .then((value) => print(value));
        },
        onLoadStart: (controller, url) {
          print("onLoadStart => $url");
        },
        onLoadEnd: (controller, url) {
          print("onLoadEnd => $url");
        },
      ));

      await _controller.initialize(_textController.text);
    }

    if (!mounted) return;
  }

  void _addNewTab(String url) {
    final controller = WebviewManager().createWebView(scrollSpeed: 0.2);
    controller.setWebviewListener(WebviewEventsListener(
      onUrlChanged: (newUrl) {
        int index = _controllers.indexOf(controller);
        if (index != -1) {
          _tabUrls[index] = newUrl;
          if (_activeTabIndex == index) {
            setState(() {
              _tabTextController.text = newUrl;
            });
          }
        }
      },
    ));

    controller.initialize(url).then((_) {
      if (mounted) setState(() {});
    });

    setState(() {
      _controllers.add(controller);
      _tabUrls.add(url);
      if (_controllers.length == 1) {
        _tabTextController.text = url;
      }
    });
  }

  void _switchTab(int index) async {
    if (_activeTabIndex == index) return;

    // 1. Deactivate current tab
    final oldController = _controllers[_activeTabIndex];
    await oldController.setClientFocus(false);
    await oldController.wasHidden(true);
    await oldController
        .executeJavaScript("document.dispatchEvent(new Event('visibilitychange'))");

    setState(() {
      _activeTabIndex = index;
      _tabTextController.text = _tabUrls[index];
    });

    // 2. Activate new tab
    final newController = _controllers[_activeTabIndex];
    await newController.wasHidden(false);
    await newController.setClientFocus(true);
  }

  void _closeTab(int index) async {
    final controller = _controllers[index];
    await controller.dispose();

    setState(() {
      _controllers.removeAt(index);
      _tabUrls.removeAt(index);

      if (_controllers.isEmpty) {
        _activeTabIndex = 0;
        _tabTextController.clear();
      } else {
        if (_activeTabIndex >= _controllers.length) {
          _activeTabIndex = _controllers.length - 1;
        }
        // Trigger activation logic for the new active tab if it changed or even if it stayed at same index but refers to a new controller now
        _tabTextController.text = _tabUrls[_activeTabIndex];
      }
    });

    if (_controllers.isNotEmpty) {
      final activeController = _controllers[_activeTabIndex];
      await activeController.wasHidden(false);
      await activeController.setClientFocus(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: useTabs ? buildTabbedUI() : buildSingleUI(),
    );
  }

  Widget buildSingleUI() {
    return Scaffold(
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
                onPressed: () {
                  _controller.goBack();
                },
                child: const Icon(Icons.arrow_left),
              ),
            ),
            SizedBox(
              height: 48,
              child: MaterialButton(
                onPressed: () {
                  _controller.goForward();
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
            child: Row(
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
        ))
      ],
    ));
  }

  Widget buildTabbedUI() {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_controllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Tab ${index + 1}"),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _closeTab(index),
                                  child: const Icon(Icons.close, size: 14),
                                ),
                              ],
                            ),
                            selected: _activeTabIndex == index,
                            onSelected: (selected) {
                              if (selected) _switchTab(index);
                            },
                            showCheckmark: true,
                            checkmarkColor: Colors.black,
                            selectedColor: Colors.white,
                            backgroundColor: Colors.purple[100],
                            labelStyle: TextStyle(
                              color: _activeTabIndex == index
                                  ? Colors.black
                                  : Colors.purple[900],
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      })..add(IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addNewTab("https://www.bing.com"),
                          iconSize: 20,
                        )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tabTextController,
                    decoration: const InputDecoration(
                      hintText: "Enter URL",
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (url) {
                      if (_controllers.isNotEmpty) {
                        _controllers[_activeTabIndex].loadUrl(url);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _controllers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _activeTabIndex,
                    children: _controllers.map((c) {
                      return ValueListenableBuilder(
                        valueListenable: c,
                        builder: (context, value, child) {
                          return c.value ? c.webviewWidget : c.loadingWidget;
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
