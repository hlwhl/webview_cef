// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#ifndef CEF_TESTS_CEFSIMPLE_SIMPLE_APP_H_
#define CEF_TESTS_CEFSIMPLE_SIMPLE_APP_H_

#include "include/cef_app.h"
#include <functional>
#include "webview_handler.h"

// Implement application-level callbacks for the browser process.
class WebviewApp : public CefApp, public CefBrowserProcessHandler {
public:
    WebviewApp(CefRefPtr<WebviewHandler> handler);
    
    // CefApp methods:
    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {
        return this;
    }
    void OnBeforeCommandLineProcessing(
                                       const CefString& process_type,
                                       CefRefPtr<CefCommandLine> command_line) override {
                                           command_line->AppendSwitch("disable-gpu");
                                           command_line->AppendSwitch("disable-gpu-compositing");
                                           #ifdef __APPLE__
                                                command_line->AppendSwitch("use-mock-keychain");
                                                command_line->AppendSwitch("single-process");
                                           #endif
                                       }
    
    // CefBrowserProcessHandler methods:
    void OnContextInitialized() override;
    CefRefPtr<CefClient> GetDefaultClient() override;
    
private:
    CefRefPtr<WebviewHandler> m_handler;
    // Include the default reference counting implementation.
    IMPLEMENT_REFCOUNTING(WebviewApp);
};

#endif  // CEF_TESTS_CEFSIMPLE_SIMPLE_APP_H_
