#ifndef WEBVIEW_PLUGIN_H
#define WEBVIEW_PLUGIN_H

#include "webview_value.h"
#include "webview_app.h"
#include <include/cef_base.h>

#include <functional>
namespace webview_cef {
    class WebviewTexture{
    public:
        virtual ~WebviewTexture(){}
        virtual void onFrame(const void* buffer, int width, int height){}
        int64_t textureId = 0;
        bool isFocused = false;
    };
    class WebviewPlugin {
    public:
        WebviewPlugin();
        ~WebviewPlugin();
        void initCallback();
        void uninitCallback();
        void HandleMethodCall(std::string name, WValue* values, std::function<void(int ,WValue*)> result);
        void sendKeyEvent(CefKeyEvent& ev);
        void setInvokeMethodFunc(std::function<void(std::string, WValue*)> func);
        void setCreateTextureFunc(std::function<std::shared_ptr<WebviewTexture>()> func);
        bool getAnyBrowserFocused();
        // True while a web editable node is focused (so the platform layer can
        // avoid double-forwarding raw character keys during IME input).
        bool isEditableFocused() const { return m_editableFocused; }

        // Native IME pipeline forwarders (driven by the Windows WM_IME_* handler).
        void imeSetCompositionNative(const std::wstring& text, int cursor);
        void imeCommitTextNative(const std::wstring& text);
        void imeFinishCompositionNative();

    private :
        bool m_editableFocused = false;
        int cursorAction(WValue *args, std::string name);
    	std::function<void(std::string, WValue*)> m_invokeFunc;
	    std::function<std::shared_ptr<WebviewTexture>()> m_createTextureFunc;
        CefRefPtr<WebviewHandler> m_handler;
	    CefRefPtr<WebviewApp> m_app;
    	std::unordered_map<int, std::shared_ptr<WebviewTexture>> m_renderers;
	    bool m_init = false;
    };

    int initCEFProcesses(CefMainArgs args);
    int initCEFProcesses();
    void startCEF();
    void doMessageLoopWork();
    void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height);
    void stopCEF();
}

#endif //WEBVIEW_PLUGIN_H
