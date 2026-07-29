# CEF 详解

CEF（Chromium Embedded Framework）是本项目的核心依赖，提供实际的网页渲染能力。本文说明 CEF 自身的文件、进程和运行机制。

## CEF 是什么

CEF 是 Chromium 浏览器的嵌入式框架包装。它将 Chromium 内核封装为一组稳定的 C API，允许桌面应用嵌入完整的 Web 浏览器。CEF 版本紧跟 Chromium 发布节奏，本项目当前使用 CEF 149（对应 Chromium 149）。

## CEF 相关文件

### 核心文件

| 文件 | 说明 |
|------|------|
| `Chromium Embedded Framework.framework` | CEF 主框架，包含 browser 进程所需的全部可执行代码和资源 |
| `libcef_dll_wrapper.a` | C API 的 C++ 适配层（`CefRefPtr`、`CefString` 等），编译为静态库 |
| `cef_sandbox.a` | Chromium 沙箱库（仅 Windows） |
| `icudtl.dat` | ICU 国际化数据（Unicode、时区、字符编码） |
| `*.pak` / `*.bin` | Chromium 资源文件（UI 资源、本地化字符串、Blink 渲染引擎资源等） |
| `snapshot_blob.bin` / `v8_context_snapshot.bin` | V8 引擎快照，加速 JS 上下文创建 |

### macOS Helper 应用

macOS 上 CEF 以**子进程**方式运行渲染、GPU 等工作。每个子进程类型对应一个独立的 `.app` bundle：

```
<AppName> Helper.app          — 渲染进程（Renderer）
<AppName> Helper (GPU).app    — GPU 进程
<AppName> Helper (Plugin).app — 插件进程（Flash 等，已废弃）
<AppName> Helper (Alerts).app — 通知/弹窗进程
```

这些 Helper 应用由构建脚本（`macos/scripts/embed_cef_helpers.rb`）在编译阶段复制到主 App 的 `Contents/Frameworks/` 目录下。每个 Helper 内部编译了一份精简的 `cef_helper` 二进制，链接了 `common/` 中的 JS 桥接代码（因为 JS ↔ C++ 桥接在渲染进程中运行）。

### 目录结构（macOS 典型）

```
webview_cef/macos/third/cef/
├── Chromium Embedded Framework.framework/
│   ├── Chromium Embedded Framework   ← 主动态库（~1GB）
│   ├── Resources/                    ← pak、icudtl.dat、本地化资源
│   └── Libraries/
│       └── libcef_dll_wrapper.a
├── cef_helper                        ← Helper 应用编译产物
├── include/                          ← C API 头文件
│   ├── cef_client.h
│   ├── cef_browser.h
│   ├── cef_render_handler.h
│   └── ...
└── Release/                          ← macOS release 构建输出
```

Web App 运行时的 Frameworks 目录：

```
<AppName>.app/
└── Contents/
    └── Frameworks/
        ├── Chromium Embedded Framework.framework/
        ├── <AppName> Helper.app/                    ← 渲染进程
        │   └── Contents/MacOS/<AppName> Helper
        ├── <AppName> Helper (GPU).app/              ← GPU 进程
        │   └── Contents/MacOS/<AppName> Helper (GPU)
        ├── FlutterMacOS.framework/
        └── webview_cef.framework/
```

## CEF 多进程架构

CEF 继承了 Chromium 的多进程架构，所有进程通过 IPC（进程间通信）协同工作。

### 进程类型

```
┌──────────────────────────────────────────────────────────────┐
│  Browser 进程（主进程）                                        │
│  - CEF 应用入口，持有 CefSettings、CefApp、CefClient           │
│  - 管理浏览器窗口生命周期                                       │
│  - 处理平台 UI 消息循环（macOS: external_message_pump）          │
│  - 路由 IPC 消息到各子进程                                      │
│  - 运行 CefBrowserProcessHandler                               │
├──────────────────────────────────────────────────────────────┤
│  Renderer 进程（渲染进程）                                      │
│  - 运行 Blink 渲染引擎 + V8 JavaScript 引擎                     │
│  - 解析 HTML/CSS、执行 JavaScript、构建 DOM、布局、绘制          │
│  - 运行 CefRenderProcessHandler（含 V8 扩展、JS 桥接）          │
│  - 每个站点/标签页各一个（取决于 ProcessMode）                  │
│  - 沙箱隔离，崩溃不影响主进程                                    │
├──────────────────────────────────────────────────────────────┤
│  GPU 进程                                                      │
│  - 处理 OpenGL/Metal/D3D 图形合成                               │
│  - OnAcceleratedPaint 共享纹理的源头                            │
│  - 本项目 GPU 纹理渲染路径的关键进程                             │
│  - 崩溃后自动重启，不影响 Browser 进程                          │
├──────────────────────────────────────────────────────────────┤
│  Network 进程（网络服务）                                       │
│  - 处理所有 HTTP/HTTPS 请求                                     │
│  - Cookie 存储和管理                                            │
│  - DNS 解析、缓存                                               │
├──────────────────────────────────────────────────────────────┤
│  Utility 进程                                                   │
│  - 音频解码、视频解码、数据解码等                                │
│  - 证书验证、代理解析等辅助任务                                  │
└──────────────────────────────────────────────────────────────┘
```

### 进程启动时序

```
1. 主进程调用 CefInitialize()
   ├── 初始化 Browser 进程
   ├── 启动 GPU 进程
   ├── 启动 Network 进程
   └── 启动其他 Utility 进程
         │
2. 调用 CefBrowserHost::CreateBrowser() / CreateBrowserSync()
   └── 启动 Renderer 进程
         │
3. Renderer 进程启动
   ├── CefExecuteProcess() 入口
   ├── 加载 V8 扩展（WebviewApp::OnWebKitInitialized）
   ├── 创建渲染窗口（OSR: 离屏渲染，无原生窗口）
   └── OnContextCreated → 页面 JavaScript 开始执行
```

### macOS 上的子进程启动

macOS 的 CEF 子进程并非直接 `fork()`，而是通过**启动独立的 Helper 应用**实现：

1. 主 App 在 `startCEF()` 中通过 `CefSettings.browser_subprocess_path` 指定 Helper 应用的路径
2. 当需要 Renderer/GPU 进程时，CEF 内部调用 `NSTask` 启动对应 Helper 的二进制
3. Helper 进程入口调用 `CefExecuteProcess()`，检查命令行 `--type` 参数确定自己的角色
4. 通过 CEF 内部的 IPC 通道连接到主 Browser 进程

代码路径（macOS）：

```objc
// CefWrapper.mm  — 设置子进程路径
NSString* subprocessPath = [NSString stringWithFormat:
    @"%@/%@.app/Contents/MacOS/%@", frameworksDir, helperName, helperName];
webview_cef::setMacCEFPaths(subprocessPath, frameworkDir, mainBundlePath);

// webview_plugin.cc  — startCEF() 传递路径给 CEF
if (!g_macSubprocessPath.empty()) {
    CefString(&cefs.browser_subprocess_path) = g_macSubprocessPath;
}

// CEF 内部 — 需要 Renderer 进程时启动 Helper
// NSTask launch → <AppName> Helper.app/Contents/MacOS/<AppName> Helper
// → CefExecuteProcess() → 检查 --type=renderer → 进入渲染进程逻辑
```

### CefExecuteProcess 的作用

`CefExecuteProcess(mainArgs, app, nullptr)` 是子进程的入口函数：

- **主进程中调用**：返回 -1，表示"当前是 browser 进程，继续执行 CefInitialize()"
- **子进程中调用**：返回 0（正常退出），表示"子进程已处理完毕，直接 exit"

```cpp
// common/webview_plugin.cc
int initCEFProcesses() {
    app = new WebviewApp();
    return CefExecuteProcess(mainArgs, app, nullptr);
    // Browser 进程返回 -1 → 继续 CefInitialize()
    // 子进程返回 0 → 不执行后续代码，直接退出
}
```

## CEF 渲染模式

### 离屏渲染（OSR — Off-Screen Rendering）

本项目使用离屏渲染模式（`windowless_rendering_enabled = true`，`SetAsWindowless(0)`）：

- CEF 将网页渲染到帧缓冲区，不创建原生窗口
- 每帧通过 `OnPaint`（软件）或 `OnAcceleratedPaint`（GPU 共享纹理）回调
- 帧数据通过 Flutter Texture 机制嵌入到 Flutter widget 树

```
CEF Renderer 进程
  │
  ▼ 渲染帧
CEF Browser 进程
  │
  ├── OnPaint(buffer, width, height)          ← 软件路径：BGRA 缓冲区
  │   └── SwapBufferFromBgraToRgba → Flutter Texture
  │
  └── OnAcceleratedPaint(shared_handle, ...)  ← GPU 路径：IOSurface / D3D11 纹理
      └── 零拷贝 → Flutter Texture
```

### 窗口模式（非本项目的默认模式）

CEF 也支持创建原生窗口（`CefWindow::CreateTopLevelWindow`），直接嵌入到原生 UI 视图层级中。本项目不使用此模式，因为它无法融入 Flutter 的 widget 树。

## CEF 缓存与数据目录

### root_cache_path

`CefSettings.root_cache_path` 指定 CEF 所有持久化数据的根目录。如果不设置，CEF 使用平台默认路径，**多个 CEF 实例可能产生文件锁冲突**。

本项目在 `startCEF()` 中设置此路径，各平台自动推导默认值（详见 [Dart 层 API](2-Dart层API.md) 中 `cachePath` 参数的说明）。

### 缓存目录结构

```
<root_cache_path>/
├── Cache/              ← HTTP 缓存（CSS、JS、图片等）
├── Code Cache/         ← V8 编译后的 JS 代码缓存
├── GPUCache/           ← GPU 着色器编译缓存
├── Local Storage/      ← Web Storage API 数据（localStorage）
├── Cookies             ← Cookie 数据库（SQLite）
├── Cookies-journal
├── Network Persistent State  ← HTTP 缓存索引
└── Preferences         ← 浏览器偏好设置
```

> **注意**：本项目通过 `disable-gpu-shader-disk-cache` 命令行参数禁用了 GPU 着色器磁盘缓存，避免在不指定 `cache-path` 时自动创建 `GPUCache` 目录。

## CEF 消息泵

### external_message_pump（macOS）

macOS 上设置 `cefs.external_message_pump = true`，CEF 不创建自己的消息循环，而是由 App 的 `NSApplication` runloop 驱动：

```cpp
// 每 16ms 调用一次，由 NSTimer 驱动
void doMessageLoopWork() {
    CefDoMessageLoopWork();
}
```

### multi_threaded_message_loop（Windows / Linux）

其他平台使用 `cefs.multi_threaded_message_loop = true`，CEF 自己管理消息循环线程。

## CEF 版本与兼容性

| 项目 | 说明 |
|------|------|
| CEF 版本 | 149.0.4 |
| Chromium 版本 | 149 |
| 支持的 macOS | 12.0+ |
| C++ 标准 | C++20 |
| API 兼容 | CEF C API（`include/cef_*.h`），使用 `libcef_dll_wrapper` 做 C++ 包装 |

## CEF 命令行开关

本项目在 `WebviewApp::OnBeforeCommandLineProcessing()` 中设置以下关键开关：

| 开关 | 作用 |
|------|------|
| `disable-gpu` / `disable-gpu-compositing` | 非 GPU 纹理构建时禁用 GPU（条件编译） |
| `disable-web-security` | 允许跨域请求 |
| `allow-running-insecure-content` | 允许在 HTTPS 页面中加载 HTTP 内容 |
| `disable-gpu-shader-disk-cache` | 禁止 GPU 着色器缓存写入磁盘 |
| `no-sandbox` | 禁用沙箱（所有平台） |
| `process-per-site` | 按站点隔离渲染进程（ProcessMode 1） |
| `process-per-tab` | 按标签隔离渲染进程（ProcessMode 2） |
| `single-process` | 单进程模式（ProcessMode 3） |
| `autoplay-policy=no-user-gesture-required` | 允许自动播放音视频 |
| `use-mock-keychain` | macOS：使用模拟钥匙串（避免权限弹窗，仅调试用） |

## 参考资料

- [CEF 官方文档](https://bitbucket.org/chromiumembedded/cef/wiki/Home)
- [Chromium 多进程架构](https://www.chromium.org/developers/design-documents/multi-process-architecture/)
- [Chromium 进程模型](https://www.chromium.org/developers/design-documents/process-models/)
- [CEF 通用用法](https://bitbucket.org/chromiumembedded/cef/wiki/GeneralUsage)
