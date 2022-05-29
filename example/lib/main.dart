import 'package:flutter/material.dart';
import 'dart:async';

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
  final _controller = WebviewController();
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String url = "https://flutter.dev/";
    _textController.text = url;
    await _controller.initialize();
    await _controller.loadUrl(url);
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Webview CEF Plugin'),
          ),
          body: Column(
            children: [
              TextField(
                controller: _textController,
                onSubmitted: (url) {
                  _textController.text = url;
                  _controller.loadUrl(url);
                },
              ),
              _controller.value ?
              Expanded(child: Webview(_controller)) : const Text("not init"),
            ],
          )),
    );
  }
}
