# Dart 层 API 参考

## 概述

Dart 层通过 `lib/` 下的类对外暴露声明式、响应式的 WebView API。所有与原生层的通信通过 `MethodChannel("webview_cef")` 完成。

## 类关系图

```
WebviewManager (单例, ValueNotifier<bool>)
  │
  ├── createWebView() ──► WebViewController (ValueNotifier<bool>)
  │                         │
  │                         ├── webviewWidget ──► WebView (StatefulWidget)
  │                         │                      │
  │                         │                      └── WebViewState
  │                         │                           + WebeViewTextInput (mixin)
  │                         │
  │                         ├── setWebviewListener() ──► WebViewEventsListener
  │                         ├── setJavaScriptChannels() ──► Set<JavascriptChannel>
  │                         └── executeJavaScript() / evaluateJavascript()
  │
  ├── methodCallhandler() ── 事件分发到对应 controller.listener
  ├── Cookie API: setCookie / deleteCookie / visitAllCookies
  └── quit() ── 关闭 CEF
```

---

## WebviewManager

**文件**：`lib/src/webview_manager.dart`

单例，继承 `ValueNotifier<bool>`。通过 `WebviewManager()` 获取实例。

### 生命周期

```
initialize() → createWebView() → [使用中] → dispose() / quit()
```

### 核心方法

| 方法 | 说明 |
|------|------|
| `initialize({String? userAgent, ProcessMode processMode = ProcessMode.processPerSite, String? cachePath})` | 启动 CEF 进程，设置 `methodCallhandler`，等待 300ms 确保初始化完成 |
| `createWebView({Widget? loading, InjectUserScripts? injectUserScripts})` | 创建 WebViewController，暂存到 `_tempWebViews` |
| `onBrowserCreated(browserIndex, browserId)` | CEF 浏览器创建完成后，将 controller 从临时表迁至 `_webViews` |
| `dispose()` | 清理 channel handler 和 webview 映射 |
| `quit()` | 关闭整个 CEF 进程（退出应用前调用） |

### 事件分发

`methodCallhandler(MethodCall call)` 处理来自原生端的所有事件回调。事件通过**两条路径**路由：

- **WebViewEventsListener**（用户通过 `setWebviewListener` 注册）：页面生命周期和导航事件
- **WebViewController 直接回调**：JS 通道、输入、焦点等内部事件

| 方法名 | 路由路径 | 终点 |
|--------|----------|------|
| `onConsoleMessage` | listener | `WebViewEventsListener.onConsoleMessage` |
| `onLoadStart` | listener | `WebViewEventsListener.onPageStarted` + 注入 LOAD_START 脚本 |
| `onLoadEnd` | listener | `WebViewEventsListener.onPageFinished` + 注入 LOAD_END 脚本 |
| `onBeforeBrowse` | listener | `WebViewEventsListener.onNavigateRequest` |
| `onLoadingProgressChange` | listener | `WebViewEventsListener.onProgressUpdated` |
| `onLoadError` | listener | `WebViewEventsListener.onPageFailed` |
| `javascriptChannelMessage` | controller | `onJavascriptChannelMessage` → `JavascriptChannel.onMessageReceived` |
| `onTooltip` | controller | `onToolTip` → `WebviewTooltip` |
| `onCursorChanged` | controller | `onCursorChanged` → `MouseRegion` cursor |
| `onFocusedNodeChangeMessage` | controller | `onFocusedNodeChangeMessage` → IME attach/detach |
| `onImeCompositionRangeChangedMessage` | controller | `onImeCompositionRangeChangedMessage` → IME 候选窗口位置 |

### Cookie API

| 方法 | 说明 |
|------|------|
| `setCookie(domain, key, value)` | 设置 Cookie |
| `deleteCookie(domain, key)` | 删除 Cookie |
| `visitAllCookies()` | 遍历所有 Cookie，返回 `Map<String, Map<String, String>>` |
| `visitUrlCookies(domain, isHttpOnly)` | 遍历指定域名的 Cookie |

### ProcessMode 枚举

通过 `initialize()` 的 `processMode` 参数控制 CEF 进程模型：

| 枚举值 | 含义 | 进程数 | 适用场景 |
|--------|------|--------|----------|
| `ProcessMode.processPerSite` | 按站点隔离（默认） | ~5-8 | 生产环境、加载任意网页 |
| `ProcessMode.processPerTab` | 按标签隔离 | 更多 | 需要最大隔离 |
| `ProcessMode.singleProcess` | 单进程 | ~1 | 调试、嵌入式/Kiosk、受信内容 |

> **注意**：单进程模式下无沙箱隔离，渲染进程崩溃会导致整个应用退出，不建议用于加载不受信第三方页面。

### cachePath 参数

通过 `initialize()` 的 `cachePath` 参数为 CEF 指定独立的缓存目录：

| 行为 | 说明 |
|------|------|
| 显式指定 | `initialize(cachePath: "/path/to/cache")`，CEF 使用该目录 |
| 不指定 | 各平台自动推导唯一路径（见下表），确保多个 App 实例共存时不冲突 |

**各平台默认路径**：

| 平台 | 默认路径 | 唯一性来源 |
|------|---------|-----------|
| macOS | `~/Library/Caches/<bundle_id>/cef` | Bundle Identifier |
| Windows | `%LOCALAPPDATA%\<exe名称>\cef` | 可执行文件名 |
| Linux / eLinux | `$XDG_CACHE_HOME/<exe名称>/cef` | `/proc/self/exe` 文件名 |

> **为什么需要？** CEF 不指定 `root_cache_path` 时使用系统默认位置，多个 CEF 实例同时运行会导致缓存目录文件锁冲突，使浏览器创建失败。设置独立路径后，多个 App（如同一框架的不同项目）可同时运行。

---

## WebViewController

**文件**：`lib/src/webview.dart`（第 34-309 行）

每个 WebView 实例对应一个 `WebViewController`，继承 `ValueNotifier<bool>`。当 `webviewWidget` 就绪时 `value` 变为 `true`。

### 核心属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `ready` | `Future<void>` | 浏览器创建完成后的 Completer |
| `webviewWidget` | `Widget` | 用于嵌入 widget 树的 WebView 组件 |
| `loadingWidget` | `Widget` | 加载前显示的占位组件 |
| `_browserId` | `int` | CEF 浏览器标识符 |
| `_textureId` | `int` | Flutter Texture id |

### 导航

| 方法 | 说明 |
|------|------|
| `initialize({String url = "about:blank"})` | 创建底层 CEF 浏览器，获取 browserId 和 textureId，完成后 `value` 变为 `true` |
| `loadUrl(String url)` | 加载指定 URL |
| `reload()` | 刷新当前页面 |
| `goBack()` / `goForward()` | 前进/后退 |
| `canGoBack()` / `canGoForward()` | 查询是否有前进/后退历史，返回 `Future<bool>` |
| `openDevTools()` | 打开 Chrome DevTools |
| `stopLoading()` | 中止当前页面加载 |
| `getTitle()` | 获取当前页面标题，返回 `Future<String?>` |

### JavaScript

| 方法 | 说明 |
|------|------|
| `executeJavaScript(String code)` | 在页面中执行 JS 代码（无返回值） |
| `evaluateJavascript(String code)` | 执行 JS 代码并返回 `Future<dynamic>` |
| `setJavaScriptChannels(Set<JavascriptChannel>)` | 注册 JS ↔ Dart 通信通道 |
| `sendJavaScriptChannelCallBack(error, result, callbackId, frameId)` | 回复 JS 端的回调请求 |

### 输入（内部方法，由 WebView widget 调用）

| 方法 | 说明 |
|------|------|
| `_cursorMove(Offset)` | 鼠标悬停 |
| `_cursorClickDown(Offset)` / `_cursorClickUp(Offset)` | 鼠标按下/释放 |
| `_cursorDragging(Offset)` | 拖拽 |
| `_setScrollDelta(Offset, dx, dy)` | 滚轮/触控板滚动 |
| `_setSize(dpi, Size)` | 表面尺寸变化 |
| `sendKeyEvent(...)` | 键盘事件（eLinux 平台使用） |

### IME

| 方法 | 说明 |
|------|------|
| `imeSetComposition(text)` | 设置正在编辑的文本 |
| `imeCommitText(text)` | 提交确认的文本 |
| `setClientFocus(bool focus)` | 设置 CEF 浏览器焦点 |

---

## WebView Widget

**文件**：`lib/src/webview.dart`（第 311 行起）

### Widget 树结构

```
Focus (焦点管理, autofocus: true)
  └── SizedBox.expand(key)
      └── SizeChangedLayoutNotifier (尺寸变化通知)
          └── Listener (指针事件采集)
              ├── onPointerHover  → cursorMove
              ├── onPointerDown   → cursorClickDown + 焦点请求
              ├── onPointerUp     → cursorClickUp
              ├── onPointerMove   → cursorDragging
              ├── onPointerSignal → setScrollDelta (滚动)
              └── onPointerPanZoomUpdate → setScrollDelta
              └── MouseRegion (光标类型显示)
                  └── Texture(textureId: controller._textureId)
```

### 焦点管理

`Focus` widget 的 `onFocusChange` 回调：
- **获得焦点**：`setClientFocus(true)`，如果当前可编辑则 `attachTextInputClient()`
- **失去焦点**：`setClientFocus(false)`，`detachTextInputClient()`

### IME Delta 处理（updateEditingValueWithDeltas）

此方法是 `DeltaTextInputClient` 接口的实现，定义在 `WebViewState` 中（非 mixin），处理组合输入：

| Delta 类型 | 处理方式 |
|-----------|---------|
| `TextEditingDeltaInsertion` | 组合中 → `imeSetComposition`；直接提交 → `imeCommitText` |
| `TextEditingDeltaDeletion` | 组合中 → `imeSetComposition` |
| `TextEditingDeltaReplacement` | 组合中 → 更新 composition；结束 → `imeCommitText` |
| `TextEditingDeltaNonTextUpdate` | 清空 composition → `imeCommitText` |

### 键盘处理（eLinux）

当 `hasNativeKeySupport == false` 时，通过 `_onKeyEvent()` 处理：
1. 将 Flutter `LogicalKeyboardKey` 映射为 Windows 虚拟键码
2. 构建 CEF 修饰键标志
3. 发送 `KEYEVENT_RAWKEYDOWN`（有字符时附带 `KEYEVENT_CHAR`）

---

## WebViewEventsListener

**文件**：`lib/src/webview_events_listener.dart`

所有回调均为可选，通过 `WebViewController.setWebviewListener()` 注册：

```dart
WebViewEventsListener(
  onConsoleMessage: (int level, String message, String source, int line) {},
  onNavigateRequest: (WebViewController controller, String url) {
    // 返回 NavigationPolicy.cancel 以阻止导航，需调用 controller.stopLoading()
    return NavigationPolicy.allow;
  },
  onPageStarted: (WebViewController controller, String url) {},
  onPageFinished: (WebViewController controller, String url) {},
  onProgressUpdated: (WebViewController controller, double progress) {},
  onPageFailed: (WebViewController controller, String url, WebViewError error) {},
)
```

> **时序保证**：所有页面事件回调（`onPageStarted`、`onPageFinished`、`onNavigateRequest`、`onProgressUpdated`、`onPageFailed`）均在 `WebViewController` 初始化完成后触发，回调内可安全调用 `getTitle()`、`loadUrl()` 等 API。

### 回调说明

| 回调 | 类型 | CEF 触发源 | 说明 |
|------|------|-----------|------|
| `onConsoleMessage` | `PageConsoleCallback` | `OnConsoleMessage` | 页面 console 日志 |
| `onNavigateRequest` | `PageNavigationDelegate` | `OnBeforeBrowse` | 导航拦截（返回 `cancel` + 调 `stopLoading()` 中止） |
| `onPageStarted` | `PageStartedCallback` | `OnLoadStart` | 页面开始加载 |
| `onPageFinished` | `PageFinishedCallback` | `OnLoadEnd` | 页面加载完成 |
| `onProgressUpdated` | `PageProgressCallback` | `OnLoadingProgressChange` | 加载进度 0.0–1.0 |
| `onPageFailed` | `PageErrorCallback` | `OnLoadError` | 加载失败，携带 `WebViewError` |

### 辅助类型

- **`NavigationPolicy`**：枚举 `cancel` / `allow`
- **`WebViewError`**：`{ int code, String message, Map<String, dynamic>? extraInfo }`，`extraInfo["url"]` 为失败 URL

---

## JavascriptChannel / JavascriptMessage

**文件**：`lib/src/webview_javascript.dart`

```dart
JavascriptChannel(
  name: 'Print',                              // 通道名，匹配 JS 侧的 window.Print
  onMessageReceived: (JavascriptMessage msg) {
    print(msg.message);                       // JS 传来的 payload
    // 回复 JS 回调
    controller.sendJavaScriptChannelCallBack(
      false,                                  // error=false 表示成功
      "{'code': '200'}",                      // 返回结果
      msg.callbackId,
      msg.frameId,
    );
  },
)
```

**JS 侧调用方式**（由 `setJavaScriptChannels` 注入）：

```javascript
// 只发送消息
$cef.Print.postMessage(JSON.stringify({msg: 'hello'}));

// 发送消息并接收回调
$cef.Print.postMessage(JSON.stringify({msg: 'hello'}), function(err, res) {
  console.log('reply:', res);
});
```

---

## WebeViewTextInput Mixin

**文件**：`lib/src/webview_textinput.dart`

`DeltaTextInputClient` mixin，提供 IME 输入连接的基础设施：

- `attachTextInputClient()` — 建立 `TextInputConnection`（Windows 上跳过，因为 Windows 通过原生 WM_IME 管道处理）
- `detachTextInputClient()` — 关闭连接
- `updateIMEComposionPosition(x, y, height, offset)` — 设置 IME 候选窗口的变换矩阵

> `updateEditingValueWithDeltas` 是 `DeltaTextInputClient` 接口方法，由 `WebViewState` 直接 override 实现（见上文 WebView Widget 部分），不在 mixin 中。

---

## 其他工具类

### InjectUserScripts / UserScript

**文件**：`lib/src/webview_inject_user_script.dart`

在 `LOAD_START` 或 `LOAD_END` 时注入的脚本，通过 `executeJavaScript` 执行。

### WebviewTooltip

**文件**：`lib/src/webview_tooltip.dart`

基于 Flutter Overlay 系统的 tooltip 实现。状态机：`hide → prepare（500ms 延迟）→ shown`。
