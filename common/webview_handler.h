// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFSIMPLE_SIMPLE_HANDLER_H_
#define CEF_TESTS_CEFSIMPLE_SIMPLE_HANDLER_H_

#include "include/cef_client.h"

#include <functional>
#include <list>

class WebviewHandler : public CefClient,
public CefDisplayHandler,
public CefLifeSpanHandler,
public CefLoadHandler,
public CefRenderHandler{
public:
    std::function<void(const void*, int32_t width, int32_t height)> onPaintCallback;
    std::function<void(std::string url)> onUrlChangedCb;
    std::function<void(std::string title)> onTitleChangedCb;
    
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
    virtual CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
    virtual CefRefPtr<CefRenderHandler> GetRenderHandler() override { return this; }
    
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
    
    // Request that all existing browser windows close.
    void CloseAllBrowsers(bool force_close);
    
    // Returns true if the Chrome runtime is enabled.
    static bool IsChromeRuntimeEnabled();
    
    void sendScrollEvent(int x, int y, int deltaX, int deltaY);
    void changeSize(float a_dpi, int width, int height);
    void cursorClick(int x, int y, bool up);
    void cursorMove(int x, int y, bool dragging);
    void sendKeyEvent(CefKeyEvent ev);
    void loadUrl(std::string url);
    void goForward();
    void goBack();
    void reload();
    void openDevTools();
    
private:
    uint32_t width = 1;
    uint32_t height = 1;
    float dpi = 1.0;
    bool is_dragging = false;
    
    // List of existing browser windows. Only accessed on the CEF UI thread.
    typedef std::list<CefRefPtr<CefBrowser>> BrowserList;
    BrowserList browser_list_;
    
    // Include the default reference counting implementation.
    IMPLEMENT_REFCOUNTING(WebviewHandler);
};

#endif  // CEF_TESTS_CEFSIMPLE_SIMPLE_HANDLER_H_
