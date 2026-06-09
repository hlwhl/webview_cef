#ifndef FLUTTER_PLUGIN_WEBVIEW_CEF_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_WEBVIEW_CEF_PLUGIN_C_API_H_

#include <flutter/plugin_registrar_windows.h>
#include <string>
#include <windows.h>


#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void WebviewCefPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

FLUTTER_PLUGIN_EXPORT int initCEFProcesses(HINSTANCE hInstance);

FLUTTER_PLUGIN_EXPORT void handleWndProcForCEF(HWND hwnd, unsigned int message, unsigned __int64 wParam, __int64 lParam);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_WEBVIEW_CEF_PLUGIN_C_API_H_
