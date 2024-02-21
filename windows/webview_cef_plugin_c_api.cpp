#include "include/webview_cef/webview_cef_plugin_c_api.h"

#include "webview_cef_plugin.h"

void WebviewCefPluginCApiRegisterWithRegistrar(
	FlutterDesktopPluginRegistrarRef registrar) {
	webview_cef::WebviewCefPlugin::RegisterWithRegistrar(registrar);
}

FLUTTER_PLUGIN_EXPORT void initCEFProcesses()
{
	webview_cef::initCEFProcesses();
}
 
FLUTTER_PLUGIN_EXPORT void handleWndProcForCEF(HWND hwnd, unsigned int message, unsigned __int64 wParam, __int64 lParam)
{
	webview_cef::WebviewCefPlugin::handleMessageProc(hwnd, message, wParam, lParam);
}
