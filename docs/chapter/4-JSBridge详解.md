# JSBridge 详解

## 概述

JSBridge 是 `webview_cef` 中最复杂的子系统，实现 JavaScript ↔ Dart 双向通信。有三条通信路径：

| 路径 | JS 入口 | 方向 | 特点 |
|------|---------|------|------|
| JavaScriptChannel（无回调） | `Print.postMessage(json)` | JS → Dart | 单向消息 |
| JavaScriptChannel（有回调） | `Print.postMessage(json, callback)` | JS → Dart → JS | 请求-响应模式 |
| evaluateJavascript | Dart 侧调用 | Dart → JS → Dart | 执行 JS 并返回值 |

涉及的关键文件：

| 文件 | 角色 |
|------|------|
| `common/webview_app.cc` | V8 扩展注册，渲染进程消息处理 |
| `common/webview_js_handler.h/cc` | `CefJSHandler`（V8 调度）、`CefJSBridge`（回调和跨进程消息） |
| `common/webview_handler.cc` | `setJavaScriptChannels`、`sendJavaScriptChannelCallBack`、`executeJavaScript` |
| `common/webview_plugin.cc` | 方法调度，`javascriptChannelMessage` 回调上行的 lambda |
| `lib/src/webview_manager.dart` | MethodChannel handler，事件分发 |
| `lib/src/webview.dart` | `setJavaScriptChannels`、`sendJavaScriptChannelCallBack`、`executeJavaScript` |
| `lib/src/webview_javascript.dart` | `JavascriptChannel`、`JavascriptMessage` 类型 |

---

## 调用链全貌

```
bridge.html                          setJavaScriptChannels               V8 扩展
──────────                           ──────────────────                  ────────
Print.postMessage(msg [, cb]) ──►    Print.postMessage = (e,r) => {      external.JavaScriptChannel
                                         external.JavaScriptChannel      external.StartRequest
                                             ('Print', e, r)             external.GetNextReqID
                                     }                                  external.EvaluateCallback
```

```
外部 (JS)                           V8 原生函数                          C++ 渲染进程
───────                             ────────────                         ────────────
external.StartRequest(...)    →     native function StartRequest()  →    CefJSHandler::Execute("StartRequest")
                                                                         CefJSBridge::StartRequest()
                                                                           → frame->SendProcessMessage(PID_BROWSER)
```

```
C++ 浏览器进程                      Dart
──────────────                      ────
WebviewHandler::OnProcessMessageReceived
  → onJavaScriptChannelMessage(...)
    → WebviewPlugin lambda
      → m_invokeFunc(...)                                                  → MethodChannel
                                                                           → WebviewManager.methodCallhandler
                                                                           → JavascriptChannel.onMessageReceived
```

---

## 第 1 步：V8 扩展注册

**位置**：`WebviewApp::OnWebKitInitialized()` (`common/webview_app.cc`)

CEF 在每个渲染进程启动时调用此方法一次。它通过 `CefRegisterExtension` 将 JS 代码注入到每个页面的 V8 上下文中，创建 `external` 和 `clientSdk` 两个全局命名空间。

注入的 JS 核心结构：

```javascript
var external = {};
var clientSdk = {};

// ── external.JavaScriptChannel(n, e, r) ──
// n = 通道名（如 "Print"）
// e = 消息体（会被 JSON.stringify 序列化）
// r = 可选回调 function(error, result)
external.JavaScriptChannel = (n, e, r) => {
    var a;
    // 如果传了回调，生成唯一函数名存入 window[a]，等待原生侧回调
    null == r
        ? a = ''
        : (a = '_' + new Date + (1e3 + Math.floor(8999 * Math.random())),
           window[a] = function(n, e) {
               return function() {
                   try { e && e.call && e.call(null, arguments[1]); }
                   finally { delete window[n]; }  // 自清理
               }
           }(a, r));
    // 发送请求：reqID 取负数，以便与 jsCmd 的正数 ID 区分
    external.StartRequest(external.GetNextReqID(), n, a, JSON.stringify(e || {}), '');
};

// ── external.StartRequest ── V8 原生函数 → CefJSHandler::Execute("StartRequest")
external.StartRequest = (nReqID, strCmd, strCallBack, strArgs, strLog) => {
    native function StartRequest();
    StartRequest(nReqID, strCmd, strCallBack, strArgs, strLog);
};

// ── external.GetNextReqID ── 原子递增的请求 ID
external.GetNextReqID = () => {
    native function GetNextReqID();
    return GetNextReqID();
};

// ── external.EvaluateCallback ── evaluateJavascript 的回调出口
external.EvaluateCallback = (nReqID, result) => {
    native function EvaluateCallback();
    EvaluateCallback(nReqID, result);
};
```

**C++ 侧**：`CefRegisterExtension("v8/extern", extensionCode, handler)` 将 `CefJSHandler` 绑定为 V8 原生函数的处理器。JS 中声明的 `native function` 会自动路由到 `CefJSHandler::Execute()`。

---

## 第 2 步：setJavaScriptChannels — 创建通道入口

**位置**：`WebviewHandler::setJavaScriptChannels()` (`common/webview_handler.cc`)

当 Dart 调用 `controller.setJavaScriptChannels({JavascriptChannel(name: 'Print')})` 时，C++ 端生成 JS 代码并执行：

```cpp
void WebviewHandler::setJavaScriptChannels(int browserId,
    const std::vector<std::string> channels) {
    std::string extensionCode = "try{";
    for (auto& channel : channels) {
        extensionCode += channel;
        extensionCode += " = {postMessage: (e,r) => {external.JavaScriptChannel('";
        extensionCode += channel;
        extensionCode += "',e,r)}};";
    }
    extensionCode += "}catch(e){console.log(e);}";
    executeJavaScript(browserId, extensionCode);
}
```

对于通道 `"Print"`，执行结果：

```javascript
try {
    Print = {postMessage: (e, r) => { external.JavaScriptChannel('Print', e, r); }};
} catch(e) { console.log(e); }
```

---

## 第 3 步：JS → C++ 跨进程消息

**位置**：`CefJSHandler::Execute("StartRequest")` → `CefJSBridge::StartRequest()` (`common/webview_js_handler.cc`)

### CefJSHandler::Execute — 原生函数调度器

```cpp
bool CefJSHandler::Execute(const CefString& name, ..., arguments, ...) {
    if (name == "StartRequest") {
        int reqId = (int)arguments[0]->GetIntValue();             // 来自 GetNextReqID
        CefString strCmd = arguments[1]->GetStringValue();        // 通道名 "Print"
        CefString strCallback = arguments[2]->GetStringValue();   // 回调函数名（或空串）
        CefString strArgs = arguments[3]->GetStringValue();       // JSON payload
        js_bridge_->StartRequest(reqId, strCmd, strCallback, strArgs);
    }
    // ... GetNextReqID, EvaluateCallback, jsCmd 等
}
```

### CefJSBridge::StartRequest — 真正发送消息

```cpp
bool CefJSBridge::StartRequest(int reqId, const CefString& strCmd,
                               const CefString& strCallback, const CefString& strArgs) {
    if (reqId > 0) { reqId *= -1; }  // 取反为负数，区分 jsCmd 的正数 ID

    auto it = startRequest_callback_.find(reqId);
    if (it == startRequest_callback_.cend()) {
        CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();
        CefRefPtr<CefFrame> frame = context->GetFrame();
        if (frame) {
            // 构造跨进程消息
            CefRefPtr<CefProcessMessage> message =
                CefProcessMessage::Create(kJSCallCppFunctionMessage);
            message->GetArgumentList()->SetString(0, strCmd);     // 通道名
            message->GetArgumentList()->SetString(1, strArgs);    // JSON payload
            message->GetArgumentList()->SetInt(2, reqId);         // 负数 reqId

            // 保存回调信息（用于后续回复）
            startRequest_callback_.emplace(reqId,
                std::make_pair(frame, strCallback));

            // ★ 发送跨进程消息：渲染进程 → 浏览器进程
            frame->SendProcessMessage(PID_BROWSER, message);
            return true;
        }
    }
    return false;
}
```

**设计要点**：`reqId` 被取反为负数，以便在 `ExecuteJSCallbackFunc` 中区分：
- `callbackId < 0` → JavaScriptChannel 路径（通过 `window[name]` 字符串执行回调）
- `callbackId > 0` → jsCmd 路径（直接调用保存的 V8 函数引用）

---

## 第 4 步：浏览器进程接收 → Dart

**位置**：`WebviewHandler::OnProcessMessageReceived()` → `WebviewPlugin` lambda → Dart

```cpp
void WebviewHandler::OnProcessMessageReceived(..., message) {
    if (message_name == kJSCallCppFunctionMessage) {
        CefString fun_name = message->GetArgumentList()->GetString(0);  // "Print"
        CefString param = message->GetArgumentList()->GetString(1);     // JSON
        int js_callback_id = message->GetArgumentList()->GetInt(2);     // 负数 reqId

        onJavaScriptChannelMessage(fun_name, param,
            to_string(js_callback_id),
            browser->GetIdentifier(),
            frame->GetIdentifier().ToString());
    }
}
```

`onJavaScriptChannelMessage` 在 `WebviewPlugin::initCallback()` 中绑定为一个 lambda，该 lambda 构建 `WValue` map（包含 `channel`、`message`、`callbackId`、`browserId`、`frameId`），然后调用 `m_invokeFunc` 将事件发送到 Dart 侧。

**Dart 侧接收**（`webview_manager.dart` → `webview.dart`）：

```dart
// WebviewManager.methodCallhandler
case 'javascriptChannelMessage':
    _webViews[browserId]?.onJavascriptChannelMessage?.call(
        call.arguments['channel'],    // "Print"
        call.arguments['message'],    // JSON payload
        call.arguments['callbackId'], // 负数 reqId 的字符串形式
        call.arguments['frameId']);

// WebViewController.onJavascriptChannelMessage
get onJavascriptChannelMessage => (channelName, message, callbackId, frameId) {
    if (_javascriptChannels.containsKey(channelName)) {
        _javascriptChannels[channelName]!.onMessageReceived(
            JavascriptMessage(message, callbackId, frameId));
    }
};
```

---

## 第 5 步：Dart 回复 → JS 回调

如果 JS 侧传了回调参数，Dart 可以回复：

```dart
controller.sendJavaScriptChannelCallBack(false, result, message.callbackId, message.frameId);
```

**C++ 浏览器进程**：`WebviewHandler::sendJavaScriptChannelCallBack` 将回复打包为 `kExecuteJsCallbackMessage` 跨进程消息，发送回渲染进程：

```cpp
CefRefPtr<CefProcessMessage> message =
    CefProcessMessage::Create(kExecuteJsCallbackMessage);
args->SetInt(0, atoi(callbackId.c_str()));  // 负数 reqId
args->SetBool(1, error);                     // false = 成功
args->SetString(2, result);                  // 返回值
frame->SendProcessMessage(PID_RENDERER, message);
```

**C++ 渲染进程**：`WebviewApp::OnProcessMessageReceived` 接收消息，调用 `CefJSBridge::ExecuteJSCallbackFunc`：

```cpp
bool CefJSBridge::ExecuteJSCallbackFunc(int callbackId, bool error,
                                        const CefString& result) {
    if (callbackId < 0) {
        // ── JavaScriptChannel 路径 ──
        auto it = startRequest_callback_.find(callbackId);
        auto frame = it->second.first;
        CefString callback = it->second.second;  // 临时函数名

        // 通过 ExecuteJavaScript 调用 window[临时函数名](reqId, result)
        std::ostringstream strStream;
        strStream << "window['" << callback.ToString() << "']("
                  << callbackId * -1 << ", " << result.ToString() << ");";
        frame->ExecuteJavaScript(strStream.str(), frame->GetURL(), 0);
        startRequest_callback_.erase(callbackId);
    } else {
        // ── jsCmd 路径 ──
        auto it = render_callback_.find(callbackId);
        auto context = it->second.first;
        auto callback = it->second.second.first;
        context->Enter();
        CefV8ValueList arguments;
        arguments.push_back(CefV8Value::CreateBool(error));
        arguments.push_back(CefV8Value::CreateString(result));
        callback->ExecuteFunction(nullptr, arguments);  // 直接调用 V8 函数
        context->Exit();
        render_callback_.erase(callbackId);
    }
}
```

JS 侧的闭包收到结果，调用用户的原始回调，然后 `delete window[name]` 自清理。

---

## evaluateJavascript 路径（Dart → JS → Dart）

与 JavaScriptChannel 不同，这条路径是 Dart 主动执行 JS 并获取返回值。

```
Dart: controller.evaluateJavascript("1 + 1")
  → MethodChannel "evaluateJavascript"
    → WebviewPlugin → Handler::executeJavaScript(code, callback)
      │
      │ 生成唯一 callbackId（纳秒时间戳）
      │ 包装代码：
      │   external.EvaluateCallback(callbackId, (function(){ return 1+1; })())
      │ js_callbacks_[callbackId] = callback  ← 保存 Dart 侧 Future 的 completer
      │
      ▼ frame->ExecuteJavaScript(wrappedCode)
JS 执行 → external.EvaluateCallback(callbackId, 2)
  → [V8 native] CefJSHandler::Execute("EvaluateCallback")
    → CefJSBridge::EvaluateCallback(callbackId, jsValue)
      → SendProcessMessage(PID_BROWSER, kEvaluateCallbackMessage)
        → WebviewHandler::OnProcessMessageReceived
          → js_callbacks_.find(callbackId) → it->second(param)
            → result(1, retValue) → Dart Future 完成
```

---

## CefJSBridge 回调映射

```cpp
class CefJSBridge {
    // startRequest_callback_ — JavaScriptChannel 路径
    // key: 负数 reqId
    // value: (Frame, callbackName字符串)
    typedef std::map<int, std::pair<CefRefPtr<CefFrame>, CefString>>
        StartRequestCallbackMap;

    // render_callback_ — jsCmd 路径
    // key: 正数 js_callback_id
    // value: (V8Context, (V8Function callback, V8Value rawdata))
    typedef std::map<int, std::pair<CefRefPtr<CefV8Context>,
        std::pair<CefRefPtr<CefV8Value>, CefRefPtr<CefV8Value>>>>
        RenderCallbackMap;
};
```

**内存管理**：当页面导航离开或 V8 上下文被释放时，`RemoveCallbackFuncWithFrame(frame)` 清除该 frame 的所有回调条目，防止悬空引用。
