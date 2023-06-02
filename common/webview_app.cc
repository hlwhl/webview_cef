// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "webview_app.h"

#include <string>

#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/views/cef_browser_view.h"
#include "include/views/cef_window.h"
#include "include/wrapper/cef_helpers.h"

namespace {

// When using the Views framework this object provides the delegate
// implementation for the CefWindow that hosts the Views-based browser.
class SimpleWindowDelegate : public CefWindowDelegate {
public:
    explicit SimpleWindowDelegate(CefRefPtr<CefBrowserView> browser_view)
    : browser_view_(browser_view) {}
    
    void OnWindowCreated(CefRefPtr<CefWindow> window) override {
        // Add the browser view and show the window.
        window->AddChildView(browser_view_);
        window->Show();
        
        // Give keyboard focus to the browser view.
        browser_view_->RequestFocus();
    }
    
    void OnWindowDestroyed(CefRefPtr<CefWindow> window) override {
        browser_view_ = nullptr;
    }
    
    bool CanClose(CefRefPtr<CefWindow> window) override {
        // Allow the window to close if the browser says it's OK.
        CefRefPtr<CefBrowser> browser = browser_view_->GetBrowser();
        if (browser)
            return browser->GetHost()->TryCloseBrowser();
        return true;
    }
    
    CefSize GetPreferredSize(CefRefPtr<CefView> view) override {
        return CefSize(1280, 720);
    }
    
private:
    CefRefPtr<CefBrowserView> browser_view_;
    
    IMPLEMENT_REFCOUNTING(SimpleWindowDelegate);
    DISALLOW_COPY_AND_ASSIGN(SimpleWindowDelegate);
};

class SimpleBrowserViewDelegate : public CefBrowserViewDelegate {
public:
    SimpleBrowserViewDelegate() {}
    
    bool OnPopupBrowserViewCreated(CefRefPtr<CefBrowserView> browser_view,
                                   CefRefPtr<CefBrowserView> popup_browser_view,
                                   bool is_devtools) override {
        // Create a new top-level Window for the popup. It will show itself after
        // creation.
        CefWindow::CreateTopLevelWindow(
                                        new SimpleWindowDelegate(popup_browser_view));
        
        // We created the Window.
        return true;
    }
    
private:
    IMPLEMENT_REFCOUNTING(SimpleBrowserViewDelegate);
    DISALLOW_COPY_AND_ASSIGN(SimpleBrowserViewDelegate);
};

}  // namespace

WebviewApp::WebviewApp(CefRefPtr<WebviewHandler> handler) {
    m_handler = handler;
}

void WebviewApp::OnContextInitialized() {
    CEF_REQUIRE_UI_THREAD();
    
    // Specify CEF browser settings here.
    CefBrowserSettings browser_settings;
    browser_settings.windowless_frame_rate = 60;
    
    std::string url = "https://www.flutter.dev/";
    
    CefWindowInfo window_info;
    window_info.SetAsWindowless(nullptr);
    
    // Create the first browser window.
    CefBrowserHost::CreateBrowser(window_info, m_handler, url, browser_settings,
                                  nullptr, nullptr);
}

CefRefPtr<CefClient> WebviewApp::GetDefaultClient() {
    // Called when a new browser window is created via the Chrome runtime UI.
    return WebviewHandler::GetInstance();
}

void WebviewApp::OnWebKitInitialized()
{
    //inject js function for jssdk
    std::string extensionCode = R"(
			var external = {};
			var clientSdk = {};
			(() => {
				clientSdk.jsCmd = (functionName, arg1, arg2, arg3) => {
					if (typeof arg1 === 'function') {
						native function jsCmd(functionName, arg1);
						return jsCmd(functionName, arg1);
					} 
					else if	 (typeof arg2 === 'function') {
                        jsonString = arg1;
                        if	(typeof arg1 !== 'string'){
						    jsonString = JSON.stringify(arg1);
                        }
						native function jsCmd(functionName, jsonString, arg2);
						return jsCmd(functionName, jsonString, arg2);
					}
					else if	 (typeof arg3 === 'function') {
                        jsonString = arg1;
                        if	(typeof arg1 !== 'string'){
						    jsonString = JSON.stringify(arg1);
                        }
						native function jsCmd(functionName, jsonString, arg2, arg3);
						return jsCmd(functionName, jsonString, arg2, arg3);
					}else {

					}
				};

                external.JavaScriptChannel = (n,e,r) => {
                    var a; 
                    null == r ? a = '' : (a = '_' + new Date + (1e3 + Math.floor(8999 * Math.random())), window[a] = function (n, e) { 
                        return function () { 
                            try {
                                e && e.call && e.call(null, arguments[1]) 
                            } finally {
                                delete window[n]
                            } 
                        } 
                    }(a, r)); 
                    try {
                        external.StartRequest(external.GetNextReqID(), n, a, JSON.stringify(e || {}), '') 
                    } catch (l) {
                        console.log('messeage send')
                    }
                }

				external.StartRequest  = (nReqID, strCmd, strCallBack, strArgs, strLog) => {
					native function StartRequest();
					StartRequest(nReqID, strCmd, strCallBack, strArgs, strLog);
				};
				external.GetNextReqID  = () => {
				  native function GetNextReqID();
				  return GetNextReqID();
				};
			})();
		 )";

    CefRefPtr<CefJSHandler> handler = new CefJSHandler();

    if (!m_render_js_bridge.get())
        m_render_js_bridge.reset(new CefJSBridge);
    handler->AttachJSBridge(m_render_js_bridge);

    CefRegisterExtension("v8/extern", extensionCode, handler);
}

void WebviewApp::OnBrowserCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDictionaryValue> extra_info)
{
    if (!m_render_js_bridge.get())
        m_render_js_bridge.reset(new CefJSBridge);
}

void WebviewApp::OnBrowserDestroyed(CefRefPtr<CefBrowser> browser)
{
}

void WebviewApp::OnContextCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context)
{
}

void WebviewApp::OnContextReleased(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context)
{
    if (m_render_js_bridge.get())
    {
        m_render_js_bridge->RemoveCallbackFuncWithFrame(frame);
    }
}

void WebviewApp::OnUncaughtException(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context, CefRefPtr<CefV8Exception> exception, CefRefPtr<CefV8StackTrace> stackTrace)
{
}

void WebviewApp::OnFocusedNodeChanged(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefDOMNode> node)
{    
    //Get node attribute
    bool is_editable = (node.get() && node->IsEditable());

    // Notify the browser of the change in focused element type.
    m_last_node_is_editable = is_editable;
    CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(kFocusedNodeChangedMessage);
    message->GetArgumentList()->SetBool(0, is_editable);
    if (is_editable) {
        CefRect rect = node->GetElementBounds();
        message->GetArgumentList()->SetInt(1, rect.x);
        message->GetArgumentList()->SetInt(2, rect.y + rect.height);
    }
    frame->SendProcessMessage(PID_BROWSER, message);
}

bool WebviewApp::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefProcessId source_process, CefRefPtr<CefProcessMessage> message)
{
    const CefString& message_name = message->GetName();
    if (message_name == kExecuteJsCallbackMessage)
    {
        int			callbackId = message->GetArgumentList()->GetInt(0);
        bool		error = message->GetArgumentList()->GetBool(1);
        CefString	result = message->GetArgumentList()->GetString(2);
        if (m_render_js_bridge.get())
        {
            m_render_js_bridge->ExecuteJSCallbackFunc(callbackId, error, result);
        }
    }

    return false;
}
