// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "webview_handler.h"

#include <sstream>
#include <string>
#include <iostream>

#include "include/base/cef_callback.h"
#include "include/cef_app.h"
#include "include/cef_parser.h"
#include "include/views/cef_browser_view.h"
#include "include/views/cef_window.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

#include "webview_js_handler.h"

namespace {

WebviewHandler* g_instance = nullptr;

// Returns a data: URI with the specified contents.
std::string GetDataURI(const std::string& data, const std::string& mime_type) {
    return "data:" + mime_type + ";base64," +
    CefURIEncode(CefBase64Encode(data.data(), data.size()), false)
        .ToString();
}

}  // namespace

WebviewHandler::WebviewHandler() {
    DCHECK(!g_instance);
    g_instance = this;
}

WebviewHandler::~WebviewHandler() {
    g_instance = nullptr;
}

// static
WebviewHandler* WebviewHandler::GetInstance() {
    return g_instance;
}

bool WebviewHandler::OnProcessMessageReceived(
    CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
     CefProcessId source_process, CefRefPtr<CefProcessMessage> message)
{
	std::string message_name = message->GetName();

    if(message_name == kJSCallCppFunctionMessage)
    {
        CefString fun_name = message->GetArgumentList()->GetString(0);
		CefString param = message->GetArgumentList()->GetString(1);
		int js_callback_id = message->GetArgumentList()->GetInt(2);

        if (fun_name.empty() || !(browser.get())) {
		    return false;
	    }

        onJavaScriptChannelMessage(
            fun_name,param,std::to_string(js_callback_id),std::to_string(frame->GetIdentifier()));
    }
    return false;
}

void WebviewHandler::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                  const CefString& title) {
    //todo: title change
    if(onTitleChangedEvent) {
        onTitleChangedEvent(title);
    }
}

void WebviewHandler::OnAddressChange(CefRefPtr<CefBrowser> browser,
                             CefRefPtr<CefFrame> frame,
                     const CefString& url) {
    if(onUrlChangedEvent) {
        onTitleChangedEvent(url);
    }
}

bool WebviewHandler::OnCursorChange(CefRefPtr<CefBrowser> browser,
                            CefCursorHandle cursor,
                            cef_cursor_type_t type,
                            const CefCursorInfo& custom_cursor_info){
    if(onCursorChangedEvent) {
        onCursorChangedEvent(type);
        return true;
    }
    return false;
}

bool WebviewHandler::OnTooltip(CefRefPtr<CefBrowser> browser, CefString& text) {
    if(onTooltipEvent) {
        onTooltipEvent(text);
        return true;
    }
    return false;
}

bool WebviewHandler::OnConsoleMessage(CefRefPtr<CefBrowser> browser,
                                      cef_log_severity_t level,
                                      const CefString& message,
                                      const CefString& source,
                                      int line){
    if(onConsoleMessageEvent){
        onConsoleMessageEvent(level, message, source, line);
    }
    return false;
}

void WebviewHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
    CEF_REQUIRE_UI_THREAD();
    
    // Add to the list of existing browsers.
    browser_list_.push_back(browser);
}

bool WebviewHandler::DoClose(CefRefPtr<CefBrowser> browser) {
    CEF_REQUIRE_UI_THREAD();    
    // Allow the close. For windowed browsers this will result in the OS close
    // event being sent.
    return false;
}

void WebviewHandler::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
    CEF_REQUIRE_UI_THREAD();
    
    // Remove from the list of existing browsers.
    BrowserList::iterator bit = browser_list_.begin();
    for (; bit != browser_list_.end(); ++bit) {
        if ((*bit)->IsSame(browser)) {
            browser_list_.erase(bit);
            break;
        }
    }
    
    if (browser_list_.empty()) {
        // All browser windows have closed. Quit the application message loop.
        CefQuitMessageLoop();
    }
}

bool WebviewHandler::OnBeforePopup(CefRefPtr<CefBrowser> browser,
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
                                  bool* no_javascript_access) {
    loadUrl(target_url);
    return true;
}

void WebviewHandler::OnLoadError(CefRefPtr<CefBrowser> browser,
                                CefRefPtr<CefFrame> frame,
                                ErrorCode errorCode,
                                const CefString& errorText,
                                const CefString& failedUrl) {
    CEF_REQUIRE_UI_THREAD();
    
    // Allow Chrome to show the error page.
    if (IsChromeRuntimeEnabled())
        return;
    
    // Don't display an error for downloaded files.
    if (errorCode == ERR_ABORTED)
        return;
    
    // Display a load error message using a data: URI.
    std::stringstream ss;
    ss << "<html><body bgcolor=\"white\">"
    "<h2>Failed to load URL "
    << std::string(failedUrl) << " with error " << std::string(errorText)
    << " (" << errorCode << ").</h2></body></html>";
    
    frame->LoadURL(GetDataURI(ss.str(), "text/html"));
}

void WebviewHandler::CloseAllBrowsers(bool force_close) {
    if (!CefCurrentlyOn(TID_UI)) {
        // Execute on the UI thread.
        //    CefPostTask(TID_UI, base::BindOnce(&SimpleHandler::CloseAllBrowsers, this,
        //                                       force_close));
        return;
    }
    
    if (browser_list_.empty())
        return;
    
    BrowserList::const_iterator it = browser_list_.begin();
    for (; it != browser_list_.end(); ++it)
        (*it)->GetHost()->CloseBrowser(force_close);
}

// static
bool WebviewHandler::IsChromeRuntimeEnabled() {
    static int value = -1;
    if (value == -1) {
        CefRefPtr<CefCommandLine> command_line =
        CefCommandLine::GetGlobalCommandLine();
        value = command_line->HasSwitch("enable-chrome-runtime") ? 1 : 0;
    }
    return value == 1;
}

void WebviewHandler::sendScrollEvent(int x, int y, int deltaX, int deltaY) {
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        CefMouseEvent ev;
        ev.x = x;
        ev.y = y;

#ifndef __APPLE__
        // The scrolling direction on Windows and Linux is different from MacOS
        deltaY = -deltaY;
        // Flutter scrolls too slowly, it looks more normal by 10x default speed.
        (*it)->GetHost()->SendMouseWheelEvent(ev, deltaX * 10, deltaY * 10);
#else
        (*it)->GetHost()->SendMouseWheelEvent(ev, deltaX, deltaY);
#endif


    }
}

void WebviewHandler::changeSize(float a_dpi, int w, int h)
{
    this->dpi = a_dpi;
    this->width = w;
    this->height = h;
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        (*it)->GetHost()->WasResized();
    }
}

void WebviewHandler::cursorClick(int x, int y, bool up)
{
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        CefMouseEvent ev;
        ev.x = x;
        ev.y = y;
        ev.modifiers = EVENTFLAG_LEFT_MOUSE_BUTTON;
        if(up && is_dragging) {
            (*it)->GetHost()->DragTargetDrop(ev);
            (*it)->GetHost()->DragSourceSystemDragEnded();
            is_dragging = false;
        } else {
            (*it)->GetHost()->SendMouseClickEvent(ev, CefBrowserHost::MouseButtonType::MBT_LEFT, up, 1);
        }
    }
}

void WebviewHandler::cursorMove(int x , int y, bool dragging)
{
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        CefMouseEvent ev;
        ev.x = x;
        ev.y = y;
        if(dragging) {
            ev.modifiers = EVENTFLAG_LEFT_MOUSE_BUTTON;
        }
        if(is_dragging && dragging) {
            (*it)->GetHost()->DragTargetDragOver(ev, DRAG_OPERATION_EVERY);
        } else {
            (*it)->GetHost()->SendMouseMoveEvent(ev, false);
        }
    }
}

bool WebviewHandler::StartDragging(CefRefPtr<CefBrowser> browser,
                                  CefRefPtr<CefDragData> drag_data,
                                  DragOperationsMask allowed_ops,
                                  int x,
                                  int y){
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        CefMouseEvent ev;
        ev.x = x;
        ev.y = y;
        ev.modifiers = EVENTFLAG_LEFT_MOUSE_BUTTON;
        (*it)->GetHost()->DragTargetDragEnter(drag_data, ev, DRAG_OPERATION_EVERY);
        is_dragging = true;
    }
    return true;
}

void WebviewHandler::sendKeyEvent(CefKeyEvent& ev)
{
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        (*it)->GetHost()->SendKeyEvent(ev);
    }
}

void WebviewHandler::loadUrl(std::string url)
{
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        (*it)->GetMainFrame()->LoadURL(url);
    }
}

void WebviewHandler::goForward() {
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        (*it)->GetMainFrame()->GetBrowser()->GoForward();
    }
}

void WebviewHandler::goBack() {
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        (*it)->GetMainFrame()->GetBrowser()->GoBack();
    }
}

void WebviewHandler::reload() {
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        (*it)->GetMainFrame()->GetBrowser()->Reload();
    }
}

void WebviewHandler::openDevTools() {
    BrowserList::const_iterator it = browser_list_.begin();
    if (it != browser_list_.end()) {
        CefWindowInfo windowInfo;
#ifdef _WIN32
        windowInfo.SetAsPopup(nullptr, "DevTools");
#endif
        (*it)->GetHost()->ShowDevTools(windowInfo, this, CefBrowserSettings(), CefPoint());
    }
}

void WebviewHandler::setCookie(const std::string& domain, const std::string& key, const std::string& value){
    CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager(nullptr);
    if(manager){
        CefCookie cookie;
		CefString(&cookie.path).FromASCII("/");
		CefString(&cookie.name).FromString(key.c_str());
		CefString(&cookie.value).FromString(value.c_str());

		if (!domain.empty()) {
			CefString(&cookie.domain).FromString(domain.c_str());
		}

		cookie.httponly = true;
		cookie.secure = false;
		std::string httpDomain = "https://" + domain + "/cookiestorage";
		manager->SetCookie(httpDomain, cookie, nullptr);
    }
}

void WebviewHandler::deleteCookie(const std::string& domain, const std::string& key)
{
    CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager(nullptr);
    if (manager) {
        std::string httpDomain = "https://" + domain + "/cookiestorage";
        manager->DeleteCookies(httpDomain, key, nullptr);
    }
}

bool WebviewHandler::visitAllCookies(std::function<void(std::map<std::string, std::map<std::string, std::string>>)> callback){
    CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager(nullptr);
    if (!manager)
	{
		return false;
	}

    CefRefPtr<WebviewCookieVisitor> cookieVisitor = new WebviewCookieVisitor();
    cookieVisitor->setOnVisitComplete(callback);

    return manager->VisitAllCookies(cookieVisitor);
}

bool WebviewHandler::visitUrlCookies(const std::string& domain, const bool& isHttpOnly, std::function<void(std::map<std::string, std::map<std::string, std::string>>)> callback){
    CefRefPtr<CefCookieManager> manager = CefCookieManager::GetGlobalManager(nullptr);
    if (!manager)
	{
		return false;
	}

    CefRefPtr<WebviewCookieVisitor> cookieVisitor = new WebviewCookieVisitor();
    cookieVisitor->setOnVisitComplete(callback);

    std::string httpDomain = "https://" + domain + "/cookiestorage";

    return manager->VisitUrlCookies(httpDomain, isHttpOnly, cookieVisitor);
}

bool WebviewHandler::setJavaScriptChannels(const std::vector<std::string> channels)
{
    std::string extensionCode = "";
    for(auto& channel : channels)
    {
        extensionCode += channel;
        extensionCode += " = (e,r) => {external.JavaScriptChannel('";
        extensionCode += channel;
        extensionCode += "',e,r)};";
    }
    return executeJavaScript(extensionCode);
}

bool WebviewHandler::sendJavaScriptChannelCallBack(const bool error, const std::string result, const std::string callbackId, const std::string frameId)
{
    CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(kExecuteJsCallbackMessage);
    CefRefPtr<CefListValue> args = message->GetArgumentList();
    args->SetInt(0, atoi(callbackId.c_str()));
    args->SetBool(1, error);
    args->SetString(2, result);
    BrowserList::iterator bit = browser_list_.begin();
    for (; bit != browser_list_.end(); ++bit) {
        CefRefPtr<CefFrame> frame = (*bit)->GetMainFrame();
        if (frame->GetIdentifier() == atoll(frameId.c_str()))
        {
            frame->SendProcessMessage(PID_RENDERER, message);
            return true;
        }
    }
    return false;
}

bool WebviewHandler::executeJavaScript(const std::string code)
{
    if(!code.empty())
    {
        BrowserList::iterator bit = browser_list_.begin();
        for (; bit != browser_list_.end(); ++bit) {
            if ((*bit).get()) {
                CefRefPtr<CefFrame> frame = (*bit)->GetMainFrame();
                if (frame) {
			        frame->ExecuteJavaScript(code, frame->GetURL(), 0);
			        return true;
		        }
            }
        }
    }
    return false;
}

void WebviewHandler::GetViewRect(CefRefPtr<CefBrowser> browser, CefRect &rect) {
    CEF_REQUIRE_UI_THREAD();
    
    rect.x = rect.y = 0;
    
    if (width < 1) {
        rect.width = 1;
    } else {
        rect.width = width;
    }
    
    if (height < 1) {
        rect.height = 1;
    } else {
        rect.height = height;
    }
}

bool WebviewHandler::GetScreenInfo(CefRefPtr<CefBrowser> browser, CefScreenInfo& screen_info) {
    //todo: hi dpi support
    screen_info.device_scale_factor  = this->dpi;
    return false;
}

void WebviewHandler::OnPaint(CefRefPtr<CefBrowser> browser, CefRenderHandler::PaintElementType type,
                            const CefRenderHandler::RectList &dirtyRects, const void *buffer, int w, int h) {
    onPaintCallback(buffer, w, h);
}
