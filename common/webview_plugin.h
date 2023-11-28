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
    };

    void initCEFProcesses(CefMainArgs args);
    void initCEFProcesses();
    void startCEF();
    void doMessageLoopWork();
    void sendKeyEvent(CefKeyEvent& ev);
    int HandleMethodCall(std::string name, WValue* values, WValue** response);
    void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height);
    void setUserAgent(WValue *userAgent);
    void setInvokeMethodFunc(std::function<void(std::string, WValue*)> func);
    void setCreateTextureFunc(std::function<std::shared_ptr<WebviewTexture>()> func);
    bool getPluginIsFocused();
}

#endif //WEBVIEW_PLUGIN_H
