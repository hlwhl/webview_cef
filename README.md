# WebView CEF

<a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/likes/webview_cef?logo=dart" alt="Pub.dev likes"/></a> <a href="https://pub.dev/packages/webview_cef" alt="Pub.dev popularity"><img src="https://img.shields.io/pub/popularity/webview_cef?logo=dart"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/points/webview_cef?logo=dart" alt="Pub.dev points"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/pub/v/webview_cef.svg" alt="latest version"/></a> <a href="https://pub.dev/packages/webview_cef"><img src="https://img.shields.io/badge/macOS%20%7C%20Windows-blue?logo=flutter" alt="Platform"/></a>

Flutter Desktop WebView backed by CEF (Chromium Embedded Framework).
This project is under heavy development, and the APIs are not stable yet.

## Index

- [Supported OSs](#supported-oss)
- [Setting Up](#setting-up)
  - [Windows <img align="center" src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="12">](#windows)
  - [macOS <img align="center" src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="12">](#macos)
- [TODOs](#todos)
- [Demo](#demo)
  - [Screenshots](#screenshots)
- [Credits](#credits)

## Supported OSs

- [x] Windows 7+ <img align="center" src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="12">
- [x] macOS 10.12+ <img align="center" src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="12">
- [ ] [Linux (WIP) <img align="center" src="https://1000logos.net/wp-content/uploads/2017/03/LINUX-LOGO.png" width="14">](https://github.com/hlwhl/webview_cef/tree/linux)

## Setting Up

### Windows <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="16">

Inside your application folder, you need to add two lines in your `windows\runner\main.cpp`.（Because of Chromium multi process architecture.)

```cpp
#include "webview_cef/webview_cef_plugin_c_api.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  //start cef deamon processes. MUST CALL FIRST
  initCEFProcesses();
```

When building the project for the first time, a prebuilt cef bin package (200MB, link in release) will be downloaded automatically, so you may wait for a longer time if you are building the project for the first time.

### macOS <img src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="15">

1. Download prebuilt cef bundles from [arm64](https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac_arm64/CEFbins-mac103.0.12-arm64.zip) or [intel](https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac_intel/mac103.0.12-Intel.zip) depends on your target machine arch.

> Note: You can also download [universal binary](https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac_universal/mac103.0.12-universal.zip) for build an mac-universal app if you want to build an mac universal app. See [#30](/../../issues/30). Thanks to [@okiabrian123](https://github.com/okiabrian123).

2. Unzip the archive and put all files into `macos/third/cef`.

3 Run the example app.

`**[HELP WANTED!]**` Finding a more elegant way to distribute the prebuilt package.

> Note: Currently the project has not been enabled with multi process support due to debug convenience. If you want to enable multi process support, you may want to enable multi process mode by changing the implementation and build your own helper bundle. (Finding a more elegant way in the future.)

## TODOs

> Pull requests are welcome.

- [x] Windows support
- [x] macOS support
- [ ] Linux support
- [ ] Multi instance support
- [ ] IME support
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

| Windows <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Windows_logo_-_2021.svg/1200px-Windows_logo_-_2021.svg.png" width="12"> | macOS <img src="https://seeklogo.com/images/A/apple-logo-52C416BDDD-seeklogo.com.png" width="11"> |
| --- | --- |
| <img src="https://user-images.githubusercontent.com/7610615/190431027-6824fac1-015d-4091-b034-dd58f79adbcb.png" width="400" /> | <img src="https://user-images.githubusercontent.com/7610615/190911381-db88cf33-70a2-4abc-9916-e563e54eb3f9.png" width="400" /> |
| <img src="https://user-images.githubusercontent.com/7610615/190431037-62ba0ea7-f7d1-4fca-8ce1-596a0a508f93.png" width="400" /> | <img src="https://user-images.githubusercontent.com/7610615/190911410-bd01e912-5482-4f9e-9dae-858874e5aaed.png" width="400" /> |
| <img src="https://user-images.githubusercontent.com/7610615/195815041-b9ec4da8-560f-4257-9303-f03a016da5c6.png" width="400" /> | <img width="400" alt="image" src="https://user-images.githubusercontent.com/7610615/195818746-e5adf0ef-dc8c-48ad-9b11-e552ca65b08a.png"> |

## Credits

This project is inspired from [**`flutter_webview_windows`**](https://github.com/jnschulze/flutter-webview-windows).
