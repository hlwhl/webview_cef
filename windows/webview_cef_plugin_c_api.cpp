#include "include/webview_cef/webview_cef_plugin_c_api.h"

#include "webview_cef_plugin.h"

void WebviewCefPluginCApiRegisterWithRegistrar(
	FlutterDesktopPluginRegistrarRef registrar) {
	webview_cef::WebviewCefPlugin::RegisterWithRegistrar(registrar);
}

FLUTTER_PLUGIN_EXPORT int initCEFProcesses(HINSTANCE hInstance)
{
	CefMainArgs main_args(hInstance);
	return webview_cef::initCEFProcesses(main_args);
}
 
FLUTTER_PLUGIN_EXPORT void handleWndProcForCEF(HWND hwnd, unsigned int message, unsigned __int64 wParam, __int64 lParam)
{
	webview_cef::WebviewCefPlugin::handleMessageProc(hwnd, message, wParam, lParam);
}
