# WebView CEF

<a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/likes/webview_cef?logo=dart" alt="Pub.dev likes"/></a> <a href="https://pub.dev/packages/webview_cef" alt="Pub.dev popularity"><img src="https://img.shields.io/pub/popularity/webview_cef?logo=dart"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/points/webview_cef?logo=dart" alt="Pub.dev points"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/v/webview_cef.svg" alt="latest version"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/badge/macOS%20%7C%20Windows%20%7C%20Linux-blue?logo=flutter" alt="Platform"/></a>

Flutter Desktop WebView backed by CEF (Chromium Embedded Framework).
This project is under heavy development, and the APIs are not stable yet.

## Index

- [Supported OSs](#supported-oss)
- [Setting Up](#setting-up)
  - [Windows <img align="center" src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="12">](#windows)
  - [macOS <img align="center" src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="12">](#macos)
  - [Linux <img align="center" src="https://1000logos.net/wp-content/uploads/2017/03/LINUX-LOGO.png" width="14">](#linux)
- [TODOs](#todos)
- [Demo](#demo)
  - [Screenshots](#screenshots)
- [Credits](#credits)

## Supported OSs

- [x] Windows 10+ <img align="center" src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="12">
- [x] macOS 10.15+ <img align="center" src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="12">
- [x] Linux (x64 and arm64) <img align="center" src="https://1000logos.net/wp-content/uploads/2017/03/LINUX-LOGO.png" width="14">

## Requirements

- Flutter >= 3.27.0
- Dart >= 3.6.0

Tested against the latest stable Flutter (3.44.x).

## Setting Up

### Windows <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="16">

Inside your application folder, you need to add some lines in your `windows\runner\main.cpp`.（Because of Chromium multi process architecture, and IME support, and also flutter rquires invoke method channel on flutter engine thread)

```cpp
//Introduce the source code of this plugin into your own project
#include "webview_cef/webview_cef_plugin_c_api.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  //start cef deamon processes. MUST CALL FIRST
  int exit_code = initCEFProcesses(instance);
  if (exit_code >= 0) {
    return exit_code;
  }
```

```cpp
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
    
    //add this line to enable cef keybord input, and enable to post messages to flutter engine thread from cef message loop thread.
    handleWndProcForCEF(msg.hwnd, msg.message, msg.wParam, msg.lParam);
  }
```

When building the project for the first time, the official CEF "Standard Distribution" (~330MB, from https://cef-builds.spotifycdn.com) is downloaded automatically into `third/cef`, and `libcef_dll_wrapper` is compiled from source. The first build therefore takes noticeably longer. The CEF version is pinned in [`third/download.cmake`](third/download.cmake) (`CEF_VERSION`); bump it there to update CEF.

### macOS <img src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="15">

To use the plugin in macOS, you'll need to clone the repository onto your project location, prefereably inside a `packages/` folder on the root of your project. 
Update your `pubspec.yaml` file to accomodate the change.
```
...

dependencies:
  # Webview
  webview_cef:
    path: ./packages/webview_cef     # Or wherever you cloned the repo
    
    
...
```

Then follow the below steps inside the `macos/` folder <b>of the cloned repository</b>.<br/><br/>

macOS uses CocoaPods (not the CMake `download.cmake` path), so the CEF binaries must be placed into `macos/third/cef` manually. The plugin is pinned to CEF **149** (Chromium 149); use the same version on every platform.

1. Download the official CEF "Standard Distribution" matching your target arch from <https://cef-builds.spotifycdn.com> (`...macosarm64.tar.bz2` for Apple Silicon, `...macosx64.tar.bz2` for Intel). The exact version string is `CEF_VERSION` in [`third/download.cmake`](third/download.cmake).

2. Build `libcef_dll_wrapper` from the downloaded distribution (it is not shipped prebuilt):
   ```bash
   cd cef_binary_<version>_macos<arch>
   mkdir build && cd build
   cmake -G Ninja -DPROJECT_ARCH=<arm64|x86_64> -DCMAKE_BUILD_TYPE=Release ..
   ninja libcef_dll_wrapper
   ```

3. Copy `Release/Chromium Embedded Framework.framework` and the built `libcef_dll_wrapper.a` into `macos/third/cef/` (inside the cloned repository, not your project).

4. Run the example app.

> Note: For a Universal (arm64 + x86_64) app, lipo the wrapper and use a universal framework. See [#30](/../../issues/30).

<br/><br/>

**`[HELP WANTED!]`** Finding a more elegant way to distribute the prebuilt package.

> Note: Currently the project has not been enabled with multi process support due to debug convenience. If you want to enable multi process support, you may want to enable multi process mode by changing the implementation and build your own helper bundle. (Finding a more elegant way in the future.)

### Linux <img src="https://1000logos.net/wp-content/uploads/2017/03/LINUX-LOGO.png" width="16">

For Linux, just adding `webview_cef` to your `pubspec.yaml` (e.g. by running `flutter pub add webview_cef`) does the job.

## TODOs

> Pull requests are welcome.

- [x] Windows support
- [x] macOS support
- [x] Linux support
- [x] Multi instance support
- [x] IME support(Only support Third party IME on Linux and Windows, Microsoft IME on Windows, and only tested Chinese input methods)
- [x] Mouse events support
- [x] JS bridge support
- [x] Cookie manipulation support
- [x] Release to pub
- [x] Trackpad support
- [ ] Better macOS binary distribution
- [ ] Easier way to integrate macOS helper bundles(multi process)
- [x] devTools support

## Demo

This demo is a simple webview app that can be used to test the `webview_cef` plugin.

<kbd>![demo_compressed](https://user-images.githubusercontent.com/7610615/190432410-c53ef1c4-33c2-461b-af29-b0ecab983579.gif)</kbd>

### Screenshots

| Windows <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="12"> | macOS <img src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="11"> | Linux <img src="https://1000logos.net/wp-content/uploads/2017/03/LINUX-LOGO.png" width="12"> |
| --- | --- | --- |
| <img src="https://user-images.githubusercontent.com/7610615/190431027-6824fac1-015d-4091-b034-dd58f79adbcb.png" width="400" /> | <img src="https://user-images.githubusercontent.com/7610615/190911381-db88cf33-70a2-4abc-9916-e563e54eb3f9.png" width="400" /> | <img src ="https://github.com/hlwhl/webview_cef/assets/49640121/50a4c2f6-1f24-4d10-9913-ad274d76cf3f" width="400" /> |
| <img src="https://user-images.githubusercontent.com/7610615/190431037-62ba0ea7-f7d1-4fca-8ce1-596a0a508f93.png" width="400" /> | <img src="https://user-images.githubusercontent.com/7610615/190911410-bd01e912-5482-4f9e-9dae-858874e5aaed.png" width="400" /> | <img src="https://github.com/hlwhl/webview_cef/assets/49640121/10a693d5-4ee0-4389-a1e8-1b0355f7c0a6" width="400" /> |
| <img src="https://user-images.githubusercontent.com/7610615/195815041-b9ec4da8-560f-4257-9303-f03a016da5c6.png" width="400" /> | <img width="400" alt="image" src="https://user-images.githubusercontent.com/7610615/195818746-e5adf0ef-dc8c-48ad-9b11-e552ca65b08a.png"> | <img src="https://github.com/hlwhl/webview_cef/assets/49640121/3a81f576-b555-4e16-8609-b3c7d6eec869" width="400" /> |

## Credits

This project is inspired from [**`flutter_webview_windows`**](https://github.com/jnschulze/flutter-webview-windows).
