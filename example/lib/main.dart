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
  final WebViewController _controller =
      WebviewManager().createWebView(const Text("not initialized"));
  final WebViewController _controller2 =
      WebviewManager().createWebView(const Text("not initialized"));

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
    WebviewManager().setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.162 Mobile Safari/537.36");
    await WebviewManager().initialize();
    String url = "https://flutter.dev/";
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
      },
    ));

    await _controller.initialize();
    await _controller2.initialize();
    await _controller.loadUrl(_textController.text);
    _controller2.loadUrl("www.baidu.com");
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
    _controller.setJavaScriptChannels(jsChannels);
    //also you can build your own jssdk by execute JavaScript code to CEF
    _controller.executeJavaScript("function abc(e){console.log(e)}");

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
                    WebviewManager().visitAllCookies();
                    Future.delayed(const Duration(milliseconds: 100), () {
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
              _controller.value
                  ? Expanded(child: _controller.webviewWidget)
                  : _controller.loadingWidget,
              _controller2.value
                  ? Expanded(child: _controller2.webviewWidget)
                  : _controller2.loadingWidget,
            ],
          ))
        ],
      )),
    );
  }
}
