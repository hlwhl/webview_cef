#ifndef WEBVIEW_PLUGIN_H
#define WEBVIEW_PLUGIN_H

#include <functional>
#include <include/cef_base.h>
#include "webview_value.h"

namespace webview_cef {
    void initCEFProcesses(CefMainArgs args);
    void initCEFProcesses();
    void createBrowser(int64_t textureId, int browserId);
    void closeBrowser(int browserId);
    void closeAllBrowser();
    void startCEF();
    void doMessageLoopWork();
    void sendKeyEvent(CefKeyEvent& ev);
    int HandleMethodCall(std::string name, WValue* values, WValue* response);
    void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height);
    void setUserAgent(WValue *userAgent);
    void setPaintCallBack(std::function<void(int64_t textureIf, const void*, int32_t , int32_t )> callback);
    void setInvokeMethodFunc(std::function<void(std::string, WValue*)> func);
    bool getPluginIsFocused();
}

#endif //WEBVIEW_PLUGIN_H
