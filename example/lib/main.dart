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
  late WebViewController _controller;
  // late WebViewController _controller2;
  final _textController = TextEditingController();
  String title = "";
  Map allCookies = {};

  @override
  void initState() {
    _controller =
        WebviewManager().createWebView(loading: const Text("not initialized"));
    // _controller2 = WebviewManager().createWindow(
    //   loading: const Text("not initialized"),
    //   name: "test",
    //   height: 600,
    //   width: 800);
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
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

    await _controller.initialize(_textController.text);
    // await _controller2.initialize("www.baidu.com");
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
    await _controller.executeJavaScript("function abc(e){return 'abc:'+ e}");
    _controller.evaluateJavascript("abc('test')").then((value) => print(value));
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
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
              // ValueListenableBuilder(
              //   valueListenable: _controller2,
              //   builder: (context, value, child) {
              //     return _controller2.value
              //         ? Expanded(child: _controller2.webviewWidget)
              //         : _controller2.loadingWidget;
              //   },
              // )
            ],
          ))
        ],
      )),
    );
  }
}
