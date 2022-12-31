import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {

  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class TabTitle {
  static int _tabID = 0;

  final int tabID;
  final ValueNotifier<String> titleNotifier;

  TabTitle(String title)
    : tabID = ++_tabID,
    titleNotifier = ValueNotifier(title);
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  final List<TabTitle> tabs = [TabTitle('Untitled')]; 

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
            indicator: null,
            tabs: tabs.map((t) {
              return Tab(
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: t.titleNotifier,
                        builder: (context, value, _) => Text(t.titleNotifier.value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          tabs.remove(t);
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          actions: [
            Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.add_to_photos_rounded),
                  onPressed: () {
                    setState(() {
                      tabs.add(TabTitle('Untitled'));
                      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                        DefaultTabController.of(context)!.animateTo(tabs.length - 1);
                      });
                    });
                  },
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: tabs.map((t) {
            return BrowserView(
              key: ValueKey(t.tabID),
              onTitleChanged: (newTitle) => t.titleNotifier.value = newTitle,
            );
          }).toList(),
        ),
      ),
      )
    );
  }
}

class BrowserView extends StatefulWidget {
  final Function(String) onTitleChanged;
  const BrowserView({
    super.key,
    required this.onTitleChanged,
  });

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _controller = WebViewController();
  final _textController = TextEditingController();

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
      onTitleChanged: widget.onTitleChanged,
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
    super.build(context);
    return Column(
      children: [
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
                  if (url.startsWith('http://')) {
                    _textController.text = url;
                    _controller.loadUrl(url);
                  } else if (url.startsWith('https://')) {
                    _textController.text = url;
                    _controller.loadUrl(url);
                  } else if (url.startsWith('www.')) {
                    _textController.text = 'https://$url';
                    _controller.loadUrl('https://$url');
                  } else {
                    _textController.text = url;
                    _controller.loadUrl('https://google.com/search?q=$url');
                  }
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
