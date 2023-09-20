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
    // _controller.setUserAgent("abctest!");
    await _controller.initialize();
    await _controller.loadUrl(url);
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
                message.frameId);
          }),
    ].toSet();
    //normal JavaScriptChannels
    await _controller.setJavaScriptChannels(jsChannels);
    //also you can build your own jssdk by execute JavaScript code to CEF
    await _controller.executeJavaScript("function abc(e){console.log(e)}");
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
          _controller.value
              ? Expanded(child: WebView(_controller))
              : const Text("not init"),
        ],
      )),
    );
  }
}
