// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFSIMPLE_SIMPLE_APP_H_
#define CEF_TESTS_CEFSIMPLE_SIMPLE_APP_H_

#include <functional>
#include "webview_handler.h"
#include "webview_js_handler.h"

// Implement application-level callbacks for the browser process.
class WebviewApp : public CefApp, public CefBrowserProcessHandler, public CefRenderProcessHandler{
public:
    WebviewApp(CefRefPtr<WebviewHandler> handler);
    
    // CefApp methods:
    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {
        return this;
    }

    CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() override { 
        return this; 
    }

    void OnBeforeCommandLineProcessing(
                                       const CefString& process_type,
                                       CefRefPtr<CefCommandLine> command_line) override {
                                           command_line->AppendSwitch("disable-gpu");
                                           command_line->AppendSwitch("disable-gpu-compositing");
                                           command_line->AppendSwitch("disable-web-security");
                                           #ifdef __APPLE__
                                                command_line->AppendSwitch("use-mock-keychain");
                                                command_line->AppendSwitch("single-process");
                                           #endif
                                           #ifdef __linux__
                                           
                                           #endif
                                       }
    
    // CefBrowserProcessHandler methods:
    void OnContextInitialized() override;
    CefRefPtr<CefClient> GetDefaultClient() override;

    // CefRenderProcessHandler methods.
    void OnWebKitInitialized() override;
    void OnBrowserCreated(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefDictionaryValue> extra_info) override;
    void OnBrowserDestroyed(CefRefPtr<CefBrowser> browser) override;
    void OnContextCreated(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame, 
        CefRefPtr<CefV8Context> context) override;
    void OnContextReleased(
        CefRefPtr<CefBrowser> browser, 
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefV8Context> context) override;
    void OnUncaughtException(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefV8Context> context,
        CefRefPtr<CefV8Exception> exception,
        CefRefPtr<CefV8StackTrace> stackTrace) override;
    void OnFocusedNodeChanged(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefRefPtr<CefDOMNode> node) override;
    bool OnProcessMessageReceived(
        CefRefPtr<CefBrowser> browser,
        CefRefPtr<CefFrame> frame,
        CefProcessId source_process,
        CefRefPtr<CefProcessMessage> message) override;
    
private:
    CefRefPtr<WebviewHandler> m_handler;

    std::shared_ptr<CefJSBridge>	m_render_js_bridge;
    bool							m_last_node_is_editable = false;

    // Include the default reference counting implementation.
    IMPLEMENT_REFCOUNTING(WebviewApp);
};

#endif  // CEF_TESTS_CEFSIMPLE_SIMPLE_APP_H_
