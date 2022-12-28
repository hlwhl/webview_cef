import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {

  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  static int tabID = 0;
  final List<int> tabs = [++tabID, ++tabID]; 

  @override
  void initState() {
    super.initState();
  }

  @override
  build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
        appBar: AppBar(
          title: TabBar(
            tabs: tabs.map((tid) {
              return Tab(
                child: Row(
                  children: [
                    Expanded(child: Text('Tab - $tid')),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          tabs.remove(tid);
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_to_photos_rounded),
              onPressed: () {
                setState(() {
                  tabs.add(++tabID);
                });
              },
            )
          ],
        ),
        body: TabBarView(
          children: tabs.map((e) {
            return BrowserView(key: ValueKey(e));
          }).toList(),
        ),
      ),
      )
    );
  }
}

class BrowserView extends StatefulWidget {
  const BrowserView({
    super.key,
  });

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _controller = WebViewController();
  final _textController = TextEditingController();
  String title = "";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    _textController.text = 'https://flutter.dev';

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
    await _controller.loadUrl(_textController.text);
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
   return Column(
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
                  _textController.text = url;
                  _controller.loadUrl(url);
                },
              ),
            ),
          ],
        ),
        _controller.value
            ? Expanded(child: WebView(_controller))
            : const Text("not init"),
      ],
    );
  }
}
