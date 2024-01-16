#ifndef WEBVIEW_PLUGIN_H
#define WEBVIEW_PLUGIN_H

#include <functional>
#include <include/cef_base.h>
#include "webview_value.h"

namespace webview_cef {
    class WebviewTexture{
    public:
        virtual ~WebviewTexture(){}
        virtual void onFrame(const void* buffer, int width, int height){}
        int64_t textureId = 0;
        bool isFocused = false;
    };

    void initCEFProcesses(CefMainArgs args, std::string userAgent = "");
    void initCEFProcesses(std::string userAgent = "");
    void startCEF(std::string userAgent);
    void doMessageLoopWork();
    void sendKeyEvent(CefKeyEvent& ev);
    int HandleMethodCall(std::string name, WValue* values, WValue** response);
    void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height);
    void setInvokeMethodFunc(std::function<void(std::string, WValue*)> func);
    void setCreateTextureFunc(std::function<std::shared_ptr<WebviewTexture>()> func);
    bool getAnyBrowserFocused();
}

#endif //WEBVIEW_PLUGIN_H
