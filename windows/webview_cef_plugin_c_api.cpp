#include "include/webview_cef/webview_cef_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "webview_cef_plugin.h"

void WebviewCefPluginCApiRegisterWithRegistrar(
	FlutterDesktopPluginRegistrarRef registrar) {
	webview_cef::WebviewCefPlugin::RegisterWithRegistrar(registrar);
}

FLUTTER_PLUGIN_EXPORT void initCEFProcesses(std::string userAgent)
{
	webview_cef::initCEFProcesses(userAgent);
}
 
FLUTTER_PLUGIN_EXPORT void handleWndProcForCEF(unsigned int message, unsigned __int64 wParam, __int64 lParam)
{
	//webview_cef::WebviewCefPlugin::handleMessageProc(message, wParam, lParam);
}
