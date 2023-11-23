import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _controller = WebViewController();
  final _textController = TextEditingController();
  String title = "";
  Map<String, dynamic> allCookies = {};
  late WebView webview = _controller.createWebView();
  late WebView webview2 = _controller.createWebView();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String url = "https://flutter.dev/";
    _textController.text = url;
    //unified interface for all platforms set user agent
    _controller.setUserAgent("abctest!");
    await _controller.initialize();
    _controller.setWebviewListener(WebviewEventsListener(
      onTitleChanged: (t) {
        setState(() {
          title = t;
        });
      },
      onUrlChanged: (url) {
        _textController.text = url;
      },
      onAllCookiesVisited: (cookies) {
        allCookies = cookies;
      },
      onUrlCookiesVisited: (cookies) {
        for (final key in cookies.keys) {
          allCookies[key] = cookies[key];
        }
      },
    ));

    _controller.loadUrl(webview.BrowserId, _textController.text);
    _controller.loadUrl(webview2.BrowserId, "https://www.baidu.com/");

    // ignore: prefer_collection_literals
    final Set<JavascriptChannel> jsChannels = [
      JavascriptChannel(
          name: 'Print',
          onMessageReceived: (JavascriptMessage message) {
            print(message.message);
            _controller.sendJavaScriptChannelCallBack(
                false,
                "{'code':'200','message':'print succeed!'}",
                message.callbackId,
                webview.BrowserId,
                message.frameId);
          }),
    ].toSet();
    //normal JavaScriptChannels
    _controller.setJavaScriptChannels(webview.BrowserId, jsChannels);
    //also you can build your own jssdk by execute JavaScript code to CEF
    _controller.executeJavaScript(
        webview.BrowserId, "function abc(e){console.log(e)}");

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
    setState(() {});
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
                    _controller.reload(webview.BrowserId);
                  },
                  child: const Icon(Icons.refresh),
                ),
              ),
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: () {
                    _controller.goBack(webview.BrowserId);
                  },
                  child: const Icon(Icons.arrow_left),
                ),
              ),
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: () {
                    _controller.goForward(webview.BrowserId);
                  },
                  child: const Icon(Icons.arrow_right),
                ),
              ),
              SizedBox(
                height: 48,
                child: MaterialButton(
                  onPressed: () {
                    _controller.openDevTools(webview.BrowserId);
                  },
                  child: const Icon(Icons.developer_mode),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: (url) {
                    _controller.loadUrl(webview.BrowserId, url);
                    _controller.visitAllCookies();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (url == "baidu.com") {
                        if (!allCookies.containsKey('.$url') ||
                            !Map.of(allCookies['.$url']).containsKey('test')) {
                          _controller.setCookie(url, 'test', 'test123');
                        } else {
                          _controller.deleteCookie(url, 'test');
                        }
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          // _controller.value ? Expanded(child: webview) : const Text("not init"),
          Expanded(
            child: Row(children: [
              Expanded(child: webview),
              Expanded(child: webview2),
            ]),
          )
        ],
      )),
    );
  }
}
