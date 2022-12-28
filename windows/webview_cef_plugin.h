#ifndef FLUTTER_PLUGIN_WEBVIEW_CEF_PLUGIN_H_
#define FLUTTER_PLUGIN_WEBVIEW_CEF_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "include/cef_app.h"

namespace webview_cef {

class WebviewCefPlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);
    static void sendKeyEvent(CefKeyEvent ev);

    WebviewCefPlugin();

    virtual ~WebviewCefPlugin();

    // Disallow copy and assign.
    WebviewCefPlugin(const WebviewCefPlugin&) = delete;
    WebviewCefPlugin& operator=(const WebviewCefPlugin&) = delete;

 private:
    // Called when a method is called on this plugin's channel from Dart.
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace webview_cef

#endif  // FLUTTER_PLUGIN_WEBVIEW_CEF_PLUGIN_H_
