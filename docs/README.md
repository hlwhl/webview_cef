# webview_cef 内部实现文档

`webview_cef` 是一个 Flutter 插件，通过嵌入 CEF（Chromium Embedded Framework）内核，
为 macOS、Windows、Linux 和 eLinux 提供 WebView 能力。

## 文档目录

| 文档 | 内容 |
|------|------|
| [架构概览](chapter/1-架构概览.md) | 分层架构、进程模型、数据流、关键设计决策 |
| [Dart 层 API](chapter/2-Dart层API.md) | WebviewManager、WebViewController、WebView widget、事件监听、JS 通道、IME、用户脚本 |
| [通用 C++ 层](chapter/3-通用C++层.md) | WebviewPlugin、WebviewHandler、WebviewApp、WValue、WebviewTexture |
| [JSBridge 详解](chapter/4-JSBridge详解.md) | V8 扩展、CefJSBridge、跨进程消息、JavaScriptChannel 与 evaluateJavascript 的完整调用链 |
| [渲染管线](chapter/5-渲染管线.md) | GPU 零拷贝 vs 软件回退、macOS Metal / Windows D3D11、外部帧时钟 |
| [平台输入处理](chapter/6-平台输入处理.md) | 鼠标/指针、macOS/Windows/Linux/eLinux 键盘、IME 组合输入 |
| [构建与集成](chapter/7-构建与集成.md) | macOS CocoaPods、Windows/Linux/eLinux CMake、CEF 下载、编译标志 |

## 核心文件速查

| 想了解... | 看这个文件 |
|-----------|----------|
| Dart 入口和事件分发 | `lib/src/webview_manager.dart` |
| WebView widget 和控制器的全部代码 | `lib/src/webview.dart` |
| C++ 方法调度中枢（所有 MethodChannel 调用在此分发） | `common/webview_plugin.cc` |
| CEF 客户端实现（浏览器生命周期、渲染、输入） | `common/webview_handler.h/cc` |
| V8 扩展和 JS 桥接 | `common/webview_app.cc` + `common/webview_js_handler.cc` |
| 最完整的平台适配参考 | `macos/Classes/CefWrapper.mm` |

## 阅读顺序建议

1. 先读 [架构概览](chapter/1-架构概览.md) 建立全局认知
2. 再读 [Dart 层 API](chapter/2-Dart层API.md) 了解对外接口
3. 然后读 [通用 C++ 层](chapter/3-通用C++层.md) 了解核心实现
4. [JSBridge 详解](chapter/4-JSBridge详解.md) 是最复杂的子系统，建议在理解前两者后阅读
5. [渲染管线](chapter/5-渲染管线.md) 和 [平台输入处理](chapter/6-平台输入处理.md) 可按需查阅
6. [构建与集成](chapter/7-构建与集成.md) 在需要了解编译配置时查阅
