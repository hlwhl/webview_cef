#include "include/webview_cef/webview_cef_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "webview_cef_plugin.h"
#include "include/cef_app.h"

void WebviewCefPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  webview_cef::WebviewCefPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

FLUTTER_PLUGIN_EXPORT void initCEFProcesses() {
	CefMainArgs mainArgs;
	CefExecuteProcess(mainArgs, nullptr, nullptr);
}