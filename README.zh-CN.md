# WebView CEF

<a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/likes/webview_cef?logo=dart" alt="Pub.dev likes"/></a> <a href="https://pub.dev/packages/webview_cef" alt="Pub.dev popularity"><img src="https://img.shields.io/pub/popularity/webview_cef?logo=dart"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/points/webview_cef?logo=dart" alt="Pub.dev points"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/v/webview_cef.svg" alt="latest version"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/badge/macOS%20%7C%20Windows%20%7C%20Linux-blue?logo=flutter" alt="Platform"/></a>

[English](README.md) · **简体中文**

基于 [CEF](https://bitbucket.org/chromiumembedded/cef)（Chromium Embedded Framework）的 Flutter **桌面端** WebView。它以离屏方式渲染一个完整的 Chromium 浏览器，并将画面呈现在 Flutter 的 `Texture` 上，因此网页内容能与你的 Flutter UI 在 Windows、macOS、Linux 上原生地合成在一起。

> 基于 **CEF 149（Chromium 149）**。

---

## 特性

- 🌐 **完整 Chromium 引擎** —— 现代 Web 标准、WebGL、HTML5 视频等。
- ⚡ **GPU 零拷贝渲染**（Windows）—— 帧直接从 Chromium 的 GPU 输出经共享 D3D11 纹理交给 Flutter/ANGLE，每帧不再做 CPU 端的 BGRA→RGBA 换色，也不再做 CPU→GPU 上传。
- 🎞️ **自适应帧率**（Windows）—— 由显示器的垂直消隐（vblank）驱动产帧，因此 webview 跟随显示器真实刷新率（如 120/144Hz），不再被限制在 60fps；静态内容则保持空闲不产帧。
- ⌨️ **中日韩输入法实时上屏** —— 原生输入法合成管线，拼音预编辑实时显示、选词正确上屏。
- 🔌 **JavaScript 桥** —— JS 调用 Dart，Dart 执行 JS。
- 🍪 **Cookie 管理** —— 读取、设置、删除 Cookie。
- 🪟 **多实例** —— 同时运行多个独立 webview。
- 📜 **用户脚本注入** —— 在文档开始/结束时注入 JS/CSS。
- 🛠️ **DevTools**、鼠标与触控板输入、导航以及加载/标题/URL 事件。

## 平台支持

| 平台 | 最低版本 | 架构 |
| --- | --- | --- |
| Windows | Windows 10 | x64 |
| macOS | macOS 10.15 | arm64、x86_64 |
| Linux | — | x64、arm64 |

## 环境要求

- Flutter **>= 3.27.0**、Dart **>= 3.6.0**（已在最新稳定版 Flutter 3.44.x 上测试）。

---

## 安装

### Windows

1. 添加依赖：

   ```bash
   flutter pub add webview_cef
   ```

2. 修改 `windows/runner/main.cpp`。由于 Chromium 的多进程架构，以及需要把输入/输入法和 method channel 调用路由到 Flutter 引擎线程，需要加两处钩子：

   ```cpp
   #include "webview_cef/webview_cef_plugin_c_api.h"

   int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                         _In_ wchar_t *command_line, _In_ int show_command) {
     // 启动 CEF 子进程，必须放在 wWinMain 最前面。
     int exit_code = initCEFProcesses(instance);
     if (exit_code >= 0) {
       return exit_code;
     }
     // ……原有 runner 初始化……
   ```

   在消息循环里把消息转发给 CEF（启用键盘输入，并让 CEF 能向 Flutter 引擎线程投递消息）：

   ```cpp
   ::MSG msg;
   while (::GetMessage(&msg, nullptr, 0, 0)) {
     ::TranslateMessage(&msg);
     ::DispatchMessage(&msg);
     handleWndProcForCEF(msg.hwnd, msg.message, msg.wParam, msg.lParam);
   }
   ```

   > 输入法由插件自动接管，runner 无需额外代码。

首次构建时会自动从 <https://cef-builds.spotifycdn.com> 下载官方 CEF *Standard Distribution*（约 330MB）到 `third/cef`，并从源码编译 `libcef_dll_wrapper`，因此第一次构建会明显较慢。

### macOS

macOS 走 CocoaPods，而不是 CMake 自动下载，所以需要手动放置 CEF 二进制。把本仓库克隆进你的项目（例如 `packages/webview_cef`），并以路径方式引用：

```yaml
dependencies:
  webview_cef:
    path: ./packages/webview_cef
```

然后在**克隆下来的仓库内**填充 `macos/third/cef`：

1. 从 <https://cef-builds.spotifycdn.com> 下载与目标架构匹配的官方 *Standard Distribution*（Apple Silicon 用 `...macosarm64.tar.bz2`，Intel 用 `...macosx64.tar.bz2`）。确切版本见 [`third/download.cmake`](third/download.cmake) 里的 `CEF_VERSION`。
2. 从下载包编译 `libcef_dll_wrapper`（官方不提供预编译）：

   ```bash
   cd cef_binary_<version>_macos<arch>
   mkdir build && cd build
   cmake -G Ninja -DPROJECT_ARCH=<arm64|x86_64> -DCMAKE_BUILD_TYPE=Release ..
   ninja libcef_dll_wrapper
   ```

3. 把 `Release/Chromium Embedded Framework.framework` 和编出来的 `libcef_dll_wrapper.a` 复制到 `macos/third/cef/`。
4. 运行 App。

> 如需 Universal（arm64 + x86_64）App，用 `lipo` 合并 wrapper 并使用 universal framework，详见 [#30](/../../issues/30)。**`[征集帮助]`** 更优雅的二进制分发方式。

### Linux

```bash
flutter pub add webview_cef
```

首次构建时自动下载 CEF（支持 x64 与 arm64）。请确保已安装 Flutter Linux 桌面工具链（`clang`、`cmake`、`ninja-build`、`libgtk-3-dev`、`pkg-config`）。

---

## 快速开始

```dart
import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

class MyWebView extends StatefulWidget {
  const MyWebView({super.key});
  @override
  State<MyWebView> createState() => _MyWebViewState();
}

class _MyWebViewState extends State<MyWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebviewManager().createWebView(
      loading: const Center(child: CircularProgressIndicator()),
    );
    _init();
  }

  Future<void> _init() async {
    await WebviewManager().initialize(); // 整个 App 调用一次
    _controller.setWebviewListener(WebviewEventsListener(
      onUrlChanged: (url) => debugPrint('url => $url'),
      onLoadEnd: (controller, url) => debugPrint('loaded => $url'),
    ));
    await _controller.initialize('https://flutter.dev');
  }

  @override
  void dispose() {
    _controller.dispose();
    WebviewManager().quit(); // 仅在整个 App 退出时调用
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller,
      builder: (_, ready, __) =>
          ready ? _controller.webviewWidget : _controller.loadingWidget,
    );
  }
}
```

完整示例（地址栏、Cookie、JS 桥、DevTools）见 [`example/`](example/)。

---

## 用法

### 生命周期

```dart
await WebviewManager().initialize(userAgent: 'my-app/1.0'); // 每个 App 一次
final controller = WebviewManager().createWebView(loading: const Text('…'));
await controller.initialize('https://example.com');
// …
controller.dispose();
WebviewManager().quit(); // App 关闭时
```

### 导航

```dart
controller.loadUrl('https://example.com');
controller.reload();
controller.goBack();
controller.goForward();
controller.openDevTools();
```

### 事件

```dart
controller.setWebviewListener(WebviewEventsListener(
  onTitleChanged: (title) {},
  onUrlChanged: (url) {},
  onLoadStart: (controller, url) {},
  onLoadEnd: (controller, url) {},
  onConsoleMessage: (level, message, source, line) {},
));
```

### JavaScript 桥

```dart
// Dart -> JS
controller.executeJavaScript("document.title = 'set from Dart'");
final result = await controller.evaluateJavascript("1 + 1"); // "2"

// JS -> Dart
controller.setJavaScriptChannels({
  JavascriptChannel(
    name: 'Print',
    onMessageReceived: (msg) {
      debugPrint(msg.message);
      controller.sendJavaScriptChannelCallBack(
          false, "{'code':'200'}", msg.callbackId, msg.frameId);
    },
  ),
});
```

### Cookie

```dart
await WebviewManager().setCookie('example.com', 'key', 'value');
await WebviewManager().deleteCookie('example.com', 'key');
final all = await WebviewManager().visitAllCookies();
final some = await WebviewManager().visitUrlCookies('example.com', false);
```

### 用户脚本注入

```dart
final scripts = InjectUserScripts()
  ..add(UserScript("console.log('at document start')", ScriptInjectTime.LOAD_START))
  ..add(UserScript("console.log('at document end')", ScriptInjectTime.LOAD_END));

final controller = WebviewManager().createWebView(injectUserScripts: scripts);
```

---

## Windows 构建选项

以下 CMake 选项可设置在插件目标上（括号内为默认值）：

| 选项 | 默认 | 作用 |
| --- | --- | --- |
| `WEBVIEW_CEF_GPU_TEXTURE` | `ON` | GPU 零拷贝渲染（CEF `OnAcceleratedPaint` → Flutter GPU 纹理）。设为 `OFF` 回退到软件像素缓冲路径。 |
| `WEBVIEW_CEF_USE_DEBUG_CEF` | `OFF` | 即使在 Debug 构建中也链接/打包 CEF 的 **Debug** 二进制。默认情况下 Debug 构建使用 Release 的 CEF 二进制，因为 CEF 的 Debug DCHECK 会在输入法过程中使离屏渲染崩溃。仅当你需要单步调试 CEF 自身时才打开。 |

## 升级 CEF

CEF/Chromium 版本只在一处管理 —— [`third/download.cmake`](third/download.cmake) 里的 `CEF_VERSION`。修改它即可升级 Windows 与 Linux 的 CEF（自动下载）。macOS 需要按上文把对应版本的发行包放进 `macos/third/cef`，并同步更新 `.github/workflows/test_macos.yaml` 里的版本号。

---

## 演示

<kbd>![demo](https://user-images.githubusercontent.com/7610615/190432410-c53ef1c4-33c2-461b-af29-b0ecab983579.gif)</kbd>

### 截图

| Windows | macOS | Linux |
| --- | --- | --- |
| <img src="https://user-images.githubusercontent.com/7610615/190431027-6824fac1-015d-4091-b034-dd58f79adbcb.png" width="400" /> | <img src="https://user-images.githubusercontent.com/7610615/190911381-db88cf33-70a2-4abc-9916-e563e54eb3f9.png" width="400" /> | <img src ="https://github.com/hlwhl/webview_cef/assets/49640121/50a4c2f6-1f24-4d10-9913-ad274d76cf3f" width="400" /> |
| <img src="https://user-images.githubusercontent.com/7610615/190431037-62ba0ea7-f7d1-4fca-8ce1-596a0a508f93.png" width="400" /> | <img src="https://user-images.githubusercontent.com/7610615/190911410-bd01e912-5482-4f9e-9dae-858874e5aaed.png" width="400" /> | <img src="https://github.com/hlwhl/webview_cef/assets/49640121/10a693d5-4ee0-4389-a1e8-1b0355f7c0a6" width="400" /> |

---

## 路线图

- [x] Windows / macOS / Linux 支持
- [x] 多实例
- [x] JavaScript 桥与 Cookie 管理
- [x] 输入法支持（Windows / Linux；已用中文输入法测试）
- [x] 鼠标与触控板输入
- [x] DevTools
- [x] GPU 渲染与自适应帧率（Windows）
- [ ] 更优的 macOS 二进制分发
- [ ] 更简单的 macOS 多进程 helper bundle 集成
- [ ] Windows 上无撕裂的 GPU 同步（keyed-mutex）

欢迎提交 PR。每个 PR 都会在 Windows、macOS、Linux 上运行构建 + `flutter analyze` CI。

## 致谢

灵感来自 [**`flutter_webview_windows`**](https://github.com/jnschulze/flutter-webview-windows)。

## 许可证

[Apache License 2.0](LICENSE)。
