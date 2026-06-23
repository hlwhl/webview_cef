import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  runApp(const MaterialApp(home: TabbedBrowserExample()));
}

class TabbedBrowserExample extends StatefulWidget {
  const TabbedBrowserExample({Key? key}) : super(key: key);

  @override
  State<TabbedBrowserExample> createState() => _TabbedBrowserExampleState();
}

class _TabbedBrowserExampleState extends State<TabbedBrowserExample> {
  final List<WebViewController> _controllers = [];
  int _activeTabIndex = 0;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    await WebviewManager().initialize();
    _addNewTab("https://www.google.com");
    _addNewTab("https://flutter.dev");
  }

  void _addNewTab(String url) {
    final controller = WebviewManager().createWebView();
    controller.initialize(url).then((_) {
      if (mounted) setState(() {});
    });
    
    setState(() {
      _controllers.add(controller);
    });
  }

  void _switchTab(int index) async {
    if (_activeTabIndex == index) return;

    // 1. Deactivate current tab
    final oldController = _controllers[_activeTabIndex];
    await oldController.setClientFocus(false);
    await oldController.wasHidden(true);
    // Optional: notify web content
    await oldController.executeJavaScript("document.dispatchEvent(new Event('visibilitychange'))");

    setState(() {
      _activeTabIndex = index;
    });

    // 2. Activate new tab
    final newController = _controllers[_activeTabIndex];
    await newController.wasHidden(false);
    await newController.setClientFocus(true);
    
    _urlController.text = ""; // Or get current URL from controller if available
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    WebviewManager().quit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tabbed CEF Browser"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_controllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text("Tab ${index + 1}"),
                    selected: _activeTabIndex == index,
                    onSelected: (selected) {
                      if (selected) _switchTab(index);
                    },
                  ),
                );
              })..add(
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addNewTab("https://www.bing.com"),
                )
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: "Enter URL",
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (url) {
                if (_controllers.isNotEmpty) {
                  _controllers[_activeTabIndex].loadUrl(url);
                }
              },
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
                          return c.value
                              ? c.webviewWidget
                              : c.loadingWidget;
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
