// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFSIMPLE_SIMPLE_HANDLER_H_
#define CEF_TESTS_CEFSIMPLE_SIMPLE_HANDLER_H_

#include "include/cef_client.h"

#include <functional>
#include <list>

#include "webview_cookieVisitor.h"

#define ColorUNDERLINE \
  0xFF000000  // Black SkColor value for underline,
              // same as Blink.
#define ColorBKCOLOR \
  0x00000000  // White SkColor value for background,
              // same as Blink.

class WebviewHandler : public CefClient,
public CefDisplayHandler,
public CefLifeSpanHandler,
public CefFocusHandler,
public CefLoadHandler,
public CefRenderHandler{
public:
    std::function<void(int64_t textureId, const void*, int32_t width, int32_t height)> onPaintCallback;
    std::function<void(std::string url)> onUrlChangedCb;
    std::function<void(std::string title)> onTitleChangedCb;
    std::function<void(std::map<std::string, std::map<std::string, std::string>>)> onAllCookieVisitedCb;
    std::function<void(std::map<std::string, std::map<std::string, std::string>>)> onUrlCookieVisitedCb;
    std::function<void(std::string, std::string, std::string, int, std::string)> onJavaScriptChannelMessage;
    std::function<void(bool editable)> onFocusedNodeChangeMessage;
    std::function<void(int32_t x, int32_t y)> onImeCompositionRangeChangedMessage;

    explicit WebviewHandler();
    ~WebviewHandler();
    
    // Provide access to the single global instance of this object.
    static WebviewHandler* GetInstance();
    
    // CefClient methods:
    virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() override {
        return this;
    }
    virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override {
        return this;
    }
    virtual CefRefPtr<CefFocusHandler> GetFocusHandler() override {
        return this;
    }
    virtual CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
    virtual CefRefPtr<CefRenderHandler> GetRenderHandler() override { return this; }

	bool OnProcessMessageReceived(
        CefRefPtr<CefBrowser> browser,
		CefRefPtr<CefFrame> frame,
		CefProcessId source_process,
		CefRefPtr<CefProcessMessage> message) override;

    
    // CefDisplayHandler methods:
    virtual void OnTitleChange(CefRefPtr<CefBrowser> browser,
                               const CefString& title) override;
    virtual void OnAddressChange(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 const CefString& url) override;
    
    // CefLifeSpanHandler methods:
    virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
    virtual bool DoClose(CefRefPtr<CefBrowser> browser) override;
    virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;
    virtual bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefFrame> frame,
                               const CefString& target_url,
                               const CefString& target_frame_name,
                               WindowOpenDisposition target_disposition,
                               bool user_gesture,
                               const CefPopupFeatures& popupFeatures,
                               CefWindowInfo& windowInfo,
                               CefRefPtr<CefClient>& client,
                               CefBrowserSettings& settings,
                               CefRefPtr<CefDictionaryValue>& extra_info,
                               bool* no_javascript_access) override;
    
    virtual void OnTakeFocus(CefRefPtr<CefBrowser> browser, bool next) override;
    virtual bool OnSetFocus(CefRefPtr<CefBrowser> browser, FocusSource source) override;
    virtual void OnGotFocus(CefRefPtr<CefBrowser> browser) override;

    // CefLoadHandler methods:
    virtual void OnLoadError(CefRefPtr<CefBrowser> browser,
                             CefRefPtr<CefFrame> frame,
                             ErrorCode errorCode,
                             const CefString& errorText,
                             const CefString& failedUrl) override;
    
    // CefRenderHandler methods:
    virtual void GetViewRect(CefRefPtr<CefBrowser> browser, CefRect& rect) override;
    virtual void OnPaint(CefRefPtr<CefBrowser> browser, PaintElementType type, const RectList& dirtyRects, const void* buffer, int width, int height) override;
    virtual bool GetScreenInfo(CefRefPtr<CefBrowser> browser, CefScreenInfo& screen_info) override;
    virtual bool StartDragging(CefRefPtr<CefBrowser> browser,
                               CefRefPtr<CefDragData> drag_data,
                               DragOperationsMask allowed_ops,
                               int x,
                               int y) override;

    virtual void OnImeCompositionRangeChanged(CefRefPtr<CefBrowser> browser,const CefRange& selection_range,const CefRenderHandler::RectList& character_bounds) override;

    // Request that all existing browser windows close.
    void CloseAllBrowsers(bool force_close);
    
    // Returns true if the Chrome runtime is enabled.
    static bool IsChromeRuntimeEnabled();

    void setBrowserId(int64_t textureId, int browserId, CefRefPtr<CefBrowser> browser = nullptr);
    void closeBrowser(int browserId);

    void sendScrollEvent(int browserId, int x, int y, int deltaX, int deltaY);
    void changeSize(int browserId, float a_dpi, int width, int height);
    void cursorClick(int browserId, int x, int y, bool up);
    void cursorMove(int browserId, int x, int y, bool dragging);
    void sendKeyEvent(CefKeyEvent& ev);
    void loadUrl(int browserId, std::string url);
    void goForward(int browserId);
    void goBack(int browserId);
    void reload(int browserId);
    void openDevTools(int browserId);

    void imeSetComposition(std::string text);
    void imeCommitText(std::string text);
    void setClientFocus(bool focus);

    void setCookie(const std::string& domain, const std::string& key, const std::string& value);
    void deleteCookie(const std::string& domain, const std::string& key);
    bool visitAllCookies();
    bool visitUrlCookies(const std::string& domain, const bool& isHttpOnly);

    bool setJavaScriptChannels(int browserId, const std::vector<std::string> channels);
    bool sendJavaScriptChannelCallBack(const bool error, const std::string result, const std::string callbackId, const int browserId, const std::string frameId);
    bool executeJavaScript(int browserId, const std::string code);
    
private:
    bool getCookieVisitor();

    uint32_t width = 1;
    uint32_t height = 1;
    float dpi = 1.0;
    bool is_dragging = false;
    CefRect prev_ime_position = CefRect();
    bool is_ime_commit = false;
    
    // List of existing browser windows. Only accessed on the CEF UI thread.
    std::unordered_map<int,int64_t> browser_textureId_map_;        // browserId -> textureId
    typedef std::unordered_map<int, CefRefPtr<CefBrowser>> BrowserMap;
    BrowserMap browser_map_;
    
    // Include the default reference counting implementation.
    IMPLEMENT_REFCOUNTING(WebviewHandler);

    CefRefPtr<WebviewCookieVisitor> m_CookieVisitor;
};

#endif  // CEF_TESTS_CEFSIMPLE_SIMPLE_HANDLER_H_
