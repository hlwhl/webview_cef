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

WebviewApp::ProcessType WebviewApp::GetProcessType(CefRefPtr<CefCommandLine> command_line)
{
    // The command-line flag won't be specified for the browser process.
	if (!command_line->HasSwitch("type"))
    {
        return BrowserProcess;
    }

	const std::string& process_type = command_line->GetSwitchValue("type");
	if (process_type == "renderer")
		return RendererProcess;
#if defined(OS_LINUX)
	else if (process_type == "zygote")
		return ZygoteProcess;
#endif
	return OtherProcess;
}

void WebviewApp::OnBeforeCommandLineProcessing(const CefString &process_type, CefRefPtr<CefCommandLine> command_line)
{
    // Pass additional command-line flags to the browser process.
	if (process_type.empty())
	{
#ifndef WEBVIEW_CEF_GPU_TEXTURE
		// The GPU shared-texture path (OnAcceleratedPaint) requires the GPU
		// compositor; only allow disabling the GPU when it is not compiled in.
		if (!m_bEnableGPU)
		{
			command_line->AppendSwitch("disable-gpu");
			command_line->AppendSwitch("disable-gpu-compositing");
		}
#endif

		command_line->AppendSwitch("disable-web-security");                                     //disable web security
		command_line->AppendSwitch("allow-running-insecure-content");                           //allow running insecure content in secure pages
		// Don't create a "GPUCache" directory when cache-path is unspecified.
		command_line->AppendSwitch("disable-gpu-shader-disk-cache");                            //disable gpu shader disk cache
        command_line->AppendSwitch("no-sandbox");

		//http://www.chromium.org/developers/design-documents/process-models
		if (m_uMode == 1)
		{
			command_line->AppendSwitch("process-per-site");                                     //each site in its own process
			command_line->AppendSwitchWithValue("renderer-process-limit", "8");              //limit renderer process count to decrease memory usage
		}
		else if (m_uMode == 2)
		{
			command_line->AppendSwitch("process-per-tab");                                      //each tab in its own process
		}
		else if (m_uMode == 3)
		{
			command_line->AppendSwitch("single-process");                                     //all in one process
		}
		command_line->AppendSwitchWithValue("autoplay-policy", "no-user-gesture-required");     //autoplay policy for media

        //Support cross domain requests
        std::string values = command_line->GetSwitchValue("disable-features");
        if (values == "")
        {
            values = "SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure";
        }
        else
        {
            values += ",SameSiteByDefaultCookies,CookiesWithoutSameSiteMustBeSecure";
        }
        if (values.find("CalculateNativeWinOcclusion") == size_t(-1))
        {
            values += ",CalculateNativeWinOcclusion";
        }

        command_line->AppendSwitchWithValue("disable-features", values);
        // for unsafe domain, add domain to whitelist
		if (!m_strFilterDomain.empty())
		{
			command_line->AppendSwitch("ignore-certificate-errors");                            //ignore certificate errors
			command_line->AppendSwitchWithValue("unsafely-treat-insecure-origin-as-secure",
                m_strFilterDomain);
		}
    }

#ifdef __APPLE__
    command_line->AppendSwitch("use-mock-keychain");
    // macOS now runs multi-process via bundled CEF helper apps (see the
    // example Runner's "Embed CEF Helpers" phase). The process model is
    // selected by m_uMode above, like the other platforms.
#endif
#ifdef __linux__
                                           
#endif
}

void WebviewApp::OnContextInitialized()
{
    CEF_REQUIRE_UI_THREAD();
//    CefBrowserSettings browser_settings;
//    browser_settings.windowless_frame_rate = 60;
//                
//    CefWindowInfo window_info;
//    window_info.SetAsWindowless(0);
//
//    // create browser
//    CefBrowserHost::CreateBrowser(window_info, m_handler, "", browser_settings, nullptr, nullptr);
    
}

// CefRefPtr<CefClient> WebviewApp::GetDefaultClient() {
//     // Called when a new browser window is created via the Chrome runtime UI.
//     return WebviewHandler::GetInstance();
// }

void WebviewApp::SetUnSafelyTreatInsecureOriginAsSecure(const CefString &strFilterDomain)
{
    m_strFilterDomain = strFilterDomain;
}


// Register V8 extension, wire JS ↔ C++ bridge
//
// Call chain:
//   $cef.Print.postMessage(json)       // JS call — Proxy auto-creates channel object
//     → $cef.JavaScriptChannel('Print', json)
//       → $cef.StartRequest(reqID, 'Print', '', json)
//         → [V8 native function] → CefJSHandler::Execute("StartRequest")
//           → CefJSBridge::StartRequest()
//             → frame->SendProcessMessage(PID_BROWSER)  ← cross-process
//               → WebviewHandler::OnProcessMessageReceived
//                 → onJavaScriptChannelMessage → Flutter Dart
//
// The $cef namespace is wrapped in a JavaScript Proxy: any property access
// (e.g. $cef.Print, $cef.MyChannel) automatically returns a {postMessage}
// object. No per-channel executeJavaScript injection is needed. Channels
// are available from the very first page load and survive all navigations.
//
// @example
// ```javascript
//   // Fire-and-forget
//   $cef.Print.postMessage(JSON.stringify({msg: 'hello'}));
//
//   // With callback: callback(error, result)
//   $cef.Print.postMessage(JSON.stringify({msg: 'hello'}), function(err, res) {
//     console.log('reply:', res);
//   });
// ```
//
// $cef namespace:
//   JavaScriptChannel(n, e, r) — n=channel name, e=payload, r=optional callback
//   StartRequest(...)           — V8 native function, sends cross-process message
//   GetNextReqID()              — monotonic request ID generator
//   EvaluateCallback(id, val)   — callback channel for evaluateJavascript
//   <any>                       — Proxy auto-creates {postMessage} for any name
void WebviewApp::OnWebKitInitialized()
{
    // Register the V8 extension that wires the JS ↔ C++ bridge.
    // The JS code below is injected into every V8 context before any page
    // script runs, so channels ($cef.Print, etc.) are available immediately.
    std::string extensionCode = R"(
        var $cef = {};
        var clientSdk = {};

        (() => {
            // ── clientSdk.jsCmd ──────────────────────────────────────────
            // Cross-process RPC: calls a C++ function by name with optional
            // parameters and a callback. Used by older SDK integrations.
            // Overloads are resolved by which argument position holds the
            // callback function:
            //   jsCmd(name, callback)
            //   jsCmd(name, jsonString, callback)
            //   jsCmd(name, jsonString, rawdata, callback)
            clientSdk.jsCmd = (functionName, arg1, arg2, arg3) => {
                if (typeof arg1 === 'function') {
                    native function jsCmd(functionName, arg1);
                    return jsCmd(functionName, arg1);
                }
                else if (typeof arg2 === 'function') {
                    jsonString = arg1;
                    if (typeof arg1 !== 'string') {
                        jsonString = JSON.stringify(arg1);
                    }
                    native function jsCmd(functionName, jsonString, arg2);
                    return jsCmd(functionName, jsonString, arg2);
                }
                else if (typeof arg3 === 'function') {
                    jsonString = arg1;
                    if (typeof arg1 !== 'string') {
                        jsonString = JSON.stringify(arg1);
                    }
                    native function jsCmd(functionName, jsonString, arg2, arg3);
                    return jsCmd(functionName, jsonString, arg2, arg3);
                }
            };

            // ── $cef.JavaScriptChannel(n, e, r) ──────────────────────────
            // Core channel dispatcher. Called by Proxy-generated channel
            // objects (e.g. $cef.Print.postMessage).
            //   n — channel name (e.g. "Print")
            //   e — message payload (string or object, JSON-stringified)
            //   r — optional callback function(error, result)
            //
            // When a callback is provided, it is wrapped in a uniquely-named
            // window function so the browser process can call it back later
            // via ExecuteJavaScript. The wrapper self-cleans by deleting
            // itself from window after the callback fires.
            $cef.JavaScriptChannel = (n, e, r) => {
                var callbackName;
                if (r == null) {
                    callbackName = '';
                } else {
                    callbackName = '_' + new Date
                        + (1e3 + Math.floor(8999 * Math.random()));
                    window[callbackName] = (function (name, fn) {
                        return function () {
                            try {
                                fn && fn.call && fn.call(null, arguments[1]);
                            } finally {
                                delete window[name];
                            }
                        };
                    })(callbackName, r);
                }

                try {
                    $cef.StartRequest(
                        $cef.GetNextReqID(),
                        n,
                        callbackName,
                        JSON.stringify(e || {}),
                        ''
                    );
                } catch (ex) {
                    console.log(
                        'JavaScriptChannel: failed to send for "'
                        + n + '"', ex
                    );
                }
            };

            // ── $cef.EvaluateCallback(id, val) ───────────────────────────
            // Callback channel for evaluateJavascript (Dart → JS → Dart).
            // The browser process wraps the JS expression in a self-invoking
            // function whose return value calls back through this native
            // binding → CefJSBridge::EvaluateCallback → PID_BROWSER.
            $cef.EvaluateCallback = (nReqID, result) => {
                native function EvaluateCallback();
                EvaluateCallback(nReqID, result);
            };

            // ── $cef.StartRequest(reqId, cmd, callback, args, log) ───────
            // V8 native function → CefJSHandler::Execute("StartRequest")
            // → CefJSBridge::StartRequest()
            // → frame->SendProcessMessage(PID_BROWSER)
            // → WebviewHandler::OnProcessMessageReceived
            // → onJavaScriptChannelMessage → Flutter Dart
            $cef.StartRequest = (nReqID, strCmd, strCallBack,
                                 strArgs, strLog) => {
                native function StartRequest();
                StartRequest(nReqID, strCmd, strCallBack, strArgs, strLog);
            };

            // ── $cef.GetNextReqID() ──────────────────────────────────────
            // Monotonically increasing request ID (atomic, thread-safe).
            // JavaScriptChannel requests use negative IDs to distinguish
            // them from jsCmd positive IDs in the callback map.
            $cef.GetNextReqID = () => {
                native function GetNextReqID();
                return GetNextReqID();
            };

            // ── $cef Proxy ──────────────────────────────────────────────
            // Proxy: any property access on $cef auto-creates a channel
            // object with postMessage. No executeJavaScript injection
            // needed — channels are available from the first page load
            // and survive all navigations.
            $cef = new Proxy($cef, {
                get: function(target, prop, receiver) {
                    if (prop in target) {
                        return Reflect.get(target, prop, receiver);
                    }
                    if (typeof prop === 'string') {
                        return {
                            postMessage: function(e, r) {
                                $cef.JavaScriptChannel(prop, e, r);
                            }
                        };
                    }
                    return Reflect.get(target, prop, receiver);
                }
            });
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
    if (!m_render_js_bridge.get()) {
        m_render_js_bridge.reset(new CefJSBridge);
    }
}

void WebviewApp::SetProcessMode(uint32_t uMode)
{
    m_uMode = uMode;
}

void WebviewApp::SetEnableGPU(bool bEnable)
{
    m_bEnableGPU = bEnable;
}

void WebviewApp::OnBeforeChildProcessLaunch(CefRefPtr<CefCommandLine> command_line)
{
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
    CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create(kFocusedNodeChangedMessage);
    message->GetArgumentList()->SetBool(0, is_editable);
    if (is_editable)
    {
        CefRect rect = node->GetElementBounds();
        message->GetArgumentList()->SetInt(1, rect.x);
        message->GetArgumentList()->SetInt(2, rect.y + rect.height);
        message->GetArgumentList()->SetInt(3, rect.height);
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
