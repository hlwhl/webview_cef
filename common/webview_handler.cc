// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "webview_handler.h"

#include <sstream>
#include <string>
#include <iostream>
#include <optional>
#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include "include/base/cef_callback.h"
#include "include/cef_app.h"
#include "include/cef_parser.h"
#include "include/views/cef_browser_view.h"
#include "include/views/cef_window.h"
#include "include/wrapper/cef_closure_task.h"
#include "include/wrapper/cef_helpers.h"

namespace {

// Returns a data: URI with the specified contents.
std::string GetDataURI(const std::string& data, const std::string& mime_type) {
    return "data:" + mime_type + ";base64," +
    CefURIEncode(CefBase64Encode(data.data(), data.size()), false)
        .ToString();
}

const std::optional<std::pair<int, int>> GetPointFromArgs(
    const flutter::EncodableValue* args) {
    const flutter::EncodableList* list =
        std::get_if<flutter::EncodableList>(args);
    if (!list || list->size() != 2) {
        return std::nullopt;
    }
    const auto x = std::get_if<int>(&(*list)[0]);
    const auto y = std::get_if<int>(&(*list)[1]);
    if (!x || !y) {
        return std::nullopt;
    }
    return std::make_pair(*x, *y);
}

const std::optional<std::tuple<double, double, double>> GetPointAnDPIFromArgs(
    const flutter::EncodableValue* args) {
    const flutter::EncodableList* list = std::get_if<flutter::EncodableList>(args);
    if (!list || list->size() != 3) {
        return std::nullopt;
    }
    const auto x = std::get_if<double>(&(*list)[0]);
    const auto y = std::get_if<double>(&(*list)[1]);
    const auto z = std::get_if<double>(&(*list)[2]);
    if (!x || !y || !z) {
        return std::nullopt;
    }
    return std::make_tuple(*x, *y, *z);
}

}

WebviewHandler::WebviewHandler(flutter::BinaryMessenger* messenger, const int browser_id) {
    const auto method_channel_name = "webview_cef/" + std::to_string(browser_id);
    browser_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        messenger,
        method_channel_name,
        &flutter::StandardMethodCodec::GetInstance());
    browser_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
    });
}

WebviewHandler::~WebviewHandler() {}

void WebviewHandler::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                  const CefString& title) {
    //todo: title change
    if(onTitleChangedCb) {
        onTitleChangedCb(title);
    }
}

void WebviewHandler::OnAddressChange(CefRefPtr<CefBrowser> browser,
                             CefRefPtr<CefFrame> frame,
                     const CefString& url) {
    if(onUrlChangedCb) {
        onUrlChangedCb(url);
    }
}

void WebviewHandler::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
    CEF_REQUIRE_UI_THREAD();
    this->browser_ = browser;
    this->browser_channel_->InvokeMethod("onBrowserCreated", nullptr);
}

bool WebviewHandler::DoClose(CefRefPtr<CefBrowser> browser) {
    CEF_REQUIRE_UI_THREAD();

    this->browser_channel_->SetMethodCallHandler(nullptr);
    this->browser_channel_ = nullptr;
    this->browser_ = nullptr;
    if (this->onBrowserClose) this->onBrowserClose();
    // Allow the close. For windowed browsers this will result in the OS close
    // event being sent.
    return false;
}

void WebviewHandler::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
    // CEF_REQUIRE_UI_THREAD();
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
std::cout << "CloseAllBrowsers" << std::endl;
    this->browser_->GetHost()->CloseBrowser(force_close);
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
    CefMouseEvent ev;
    ev.x = x;
    ev.y = y;

#ifndef __APPLE__
    // The scrolling direction on Windows and Linux is different from MacOS
    deltaY = -deltaY;
    // Flutter scrolls too slowly, it looks more normal by 10x default speed.
    this->browser_->GetHost()->SendMouseWheelEvent(ev, deltaX * 10, deltaY * 10);
#else
    this->browser_->GetHost()->SendMouseWheelEvent(ev, deltaX, deltaY);
#endif
}

void WebviewHandler::changeSize(float a_dpi, int w, int h)
{
    this->dpi_ = a_dpi;
    this->width_ = w;
    this->height_ = h;
    this->browser_->GetHost()->WasResized();
}

void WebviewHandler::cursorClick(int x, int y, bool up)
{
    CefMouseEvent ev;
    ev.x = x;
    ev.y = y;
    ev.modifiers = EVENTFLAG_LEFT_MOUSE_BUTTON;
    if(up && is_dragging_) {
        this->browser_->GetHost()->DragTargetDrop(ev);
        this->browser_->GetHost()->DragSourceSystemDragEnded();
        is_dragging_ = false;
    } else {
        this->browser_->GetHost()->SendMouseClickEvent(ev, CefBrowserHost::MouseButtonType::MBT_LEFT, up, 1);
    }
}

void WebviewHandler::cursorMove(int x , int y, bool dragging)
{
    CefMouseEvent ev;
    ev.x = x;
    ev.y = y;
    if(dragging) {
        ev.modifiers = EVENTFLAG_LEFT_MOUSE_BUTTON;
    }
    if(is_dragging_ && dragging) {
        this->browser_->GetHost()->DragTargetDragOver(ev, DRAG_OPERATION_EVERY);
    } else {
        this->browser_->GetHost()->SendMouseMoveEvent(ev, false);
    }
}

bool WebviewHandler::StartDragging(CefRefPtr<CefBrowser> browser,
                                  CefRefPtr<CefDragData> drag_data,
                                  DragOperationsMask allowed_ops,
                                  int x,
                                  int y){
    CefMouseEvent ev;
    ev.x = x;
    ev.y = y;
    ev.modifiers = EVENTFLAG_LEFT_MOUSE_BUTTON;
    this->browser_->GetHost()->DragTargetDragEnter(drag_data, ev, DRAG_OPERATION_EVERY);
    is_dragging_ = true;
    return true;
}

void WebviewHandler::sendKeyEvent(CefKeyEvent ev)
{
    this->browser_->GetHost()->SendKeyEvent(ev);
}

void WebviewHandler::loadUrl(std::string url)
{
    this->browser_->GetMainFrame()->LoadURL(url);
}

void WebviewHandler::goForward() {
    this->browser_->GetMainFrame()->GetBrowser()->GoForward();
}

void WebviewHandler::goBack() {
    this->browser_->GetMainFrame()->GetBrowser()->GoBack();
}

void WebviewHandler::reload() {
    this->browser_->GetMainFrame()->GetBrowser()->Reload();
}

void WebviewHandler::openDevTools() {
    CefWindowInfo windowInfo;
#ifdef _WIN32
    windowInfo.SetAsPopup(nullptr, "DevTools");
#endif
    this->browser_->GetHost()->ShowDevTools(windowInfo, this, CefBrowserSettings(), CefPoint());
}

void WebviewHandler::GetViewRect(CefRefPtr<CefBrowser> browser, CefRect &rect) {
    CEF_REQUIRE_UI_THREAD();

    rect.x = rect.y = 0;
    if (width_ < 1) {
        rect.width = 1;
    } else {
        rect.width = width_;
    }

    if (height_ < 1) {
        rect.height = 1;
    } else {
        rect.height = height_;
    }
}

bool WebviewHandler::GetScreenInfo(CefRefPtr<CefBrowser> browser, CefScreenInfo& screen_info) {
    //todo: hi dpi support
    screen_info.device_scale_factor  = this->dpi_;
    return false;
}

void WebviewHandler::OnPaint(CefRefPtr<CefBrowser> browser, CefRenderHandler::PaintElementType type,
                            const CefRenderHandler::RectList &dirtyRects, const void *buffer, int w, int h) {
    onPaintCallback(buffer, w, h);
}

void WebviewHandler::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    if (!this->browser_) {
        result->Error("browser not ready yet");
        return;
    }

    if (method_call.method_name().compare("loadUrl") == 0) {
        if (const auto url = std::get_if<std::string>(method_call.arguments())) {
            this->loadUrl(*url);
            return result->Success();
        }
    }
    else if (method_call.method_name().compare("setSize") == 0) {
        auto tuple = GetPointAnDPIFromArgs(method_call.arguments());
        if (tuple) {
            const auto [dpi, width, height] = tuple.value();
            this->changeSize(
                static_cast<float>(dpi),
                static_cast<int>(width),
                static_cast<int>(height)
            );
        }

        result->Success();
    }
    else if (method_call.method_name().compare("cursorClickDown") == 0) {
        const auto point = GetPointFromArgs(method_call.arguments());
        this->cursorClick(point->first, point->second, false);
        result->Success();
    }
    else if (method_call.method_name().compare("cursorClickUp") == 0) {
        const auto point = GetPointFromArgs(method_call.arguments());
        this->cursorClick(point->first, point->second, true);
        result->Success();
    }
    else if (method_call.method_name().compare("cursorMove") == 0) {
        const auto point = GetPointFromArgs(method_call.arguments());
        this->cursorMove(point->first, point->second, false);
        result->Success();
    }
    else if (method_call.method_name().compare("cursorDragging") == 0) {
        const auto point = GetPointFromArgs(method_call.arguments());
        this->cursorMove(point->first, point->second, true);
        result->Success();
    }
    else if (method_call.method_name().compare("setScrollDelta") == 0) {
        const flutter::EncodableList* list =
            std::get_if<flutter::EncodableList>(method_call.arguments());
        const auto x = *std::get_if<int>(&(*list)[0]);
        const auto y = *std::get_if<int>(&(*list)[1]);
        const auto deltaX = *std::get_if<int>(&(*list)[2]);
        const auto deltaY = *std::get_if<int>(&(*list)[3]);
        this->sendScrollEvent(x, y, deltaX, deltaY);
        result->Success();
    }
    else if (method_call.method_name().compare("goForward") == 0) {
        this->goForward();
        result->Success();
    }
    else if (method_call.method_name().compare("goBack") == 0) {
        this->goBack();
        result->Success();
    }
    else if (method_call.method_name().compare("reload") == 0) {
        this->reload();
        result->Success();
    }
    else if (method_call.method_name().compare("openDevTools") == 0) {
        this->openDevTools();
        result->Success();
    }
    else if (method_call.method_name().compare("dispose") == 0) {
        this->browser_->GetHost()->CloseBrowser(false);
        result->Success();
    }
    else {
        result->NotImplemented();
    }
}
