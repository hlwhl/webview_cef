## 0.2.3
- Adapted to the latest stable Flutter (tested on 3.44.x).
- Raised minimum supported Flutter to 3.27.0 / Dart 3.6.0.
- Migrated deprecated APIs (`Color.withOpacity` -> `withValues`, `Overlay.of` non-null, generic typedef, `print` -> `debugPrint`, `TextInputClient.onFocusReceived`) and bumped `flutter_lints` to ^5.
- Raised minimum Windows to 10 and minimum macOS deployment target to 10.15; refreshed example desktop runner templates.
- Upgraded CEF to 149 (Chromium 149) on all platforms, unified in `third/download.cmake`.
- Windows now consumes the official CEF Standard Distribution and builds `libcef_dll_wrapper` from source (no more custom prebuilt package); plugin builds as C++20 (required by CEF 149).
- Fixed CEF API drift: `OnBeforePopup` popup_id, `CefFrame::GetIdentifier()` -> string, and a C++20 `EncodableValue(nullptr)`/variant crash on Windows.
- Fixed a per-event memory leak in the Windows native→Dart message dispatch.
- Fixed command-line switch typos (`no-sanbox` -> `no-sandbox`, stray space in `renderer-process-limit`).
- Removed the unused federated platform-interface scaffolding (`WebviewCefPlatform` / `MethodChannelWebviewCef` / `getPlatformVersion`) and the `plugin_platform_interface` dependency; the public API is `WebviewManager` / `WebViewController`.
- Housekeeping: stopped tracking the downloaded CEF headers in git, added Windows/macOS CI, and cleaned up dead example code.

## 0.2.0
- Linux support!
- Multiple instances support.
- js eval support.

## 0.1.0
- JS bridge support (Thanks to @SinyimZhi)
- Cookie manipulation support (Thanks to @SinyimZhi)
- [Windows] fix compile error after upgrade from a lower version

## 0.0.9

- [Windows] Fixed crash caused by frame buffer lock.
- [Windows] Fixed WebGL support.

## 0.0.8

- Added support to build macOS universal app.
- Refined scrolling for different platform.
- Added search bar features in example project.
- Added title & url change aware in UI.

## 0.0.7

- Basic characters input support.
- Added back, forward, reload APIs.
- Mouse move events support.
- HTML5 drag & drop support.

## 0.0.6

- Fixed macOS compile issue.

## 0.0.5

1. Initial support for macOS.
2. Touchpad support (based on flutter 3.3).
3. Hi-DPI display support.

## 0.0.3

- Fixed compile issue on non-utf8 machines.

## 0.0.1

- Webview CEF plugin for Flutter Desktop.
- Windows support only.
