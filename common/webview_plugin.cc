#include "webview_plugin.h"

#include "webview_app.h"

#include <math.h>
#include <memory>
#include <thread>
#include <iostream>
#include <optional>
// #include <mutex>

namespace webview_cef {
	bool init = false;
	bool isFocused = false;
	std::function<void(std::string, WValue*)> invokeFunc;
    
    CefRefPtr<WebviewHandler> handler(new WebviewHandler());
    CefRefPtr<WebviewApp> app(new WebviewApp(handler));
    CefMainArgs mainArgs;

	static const std::optional<std::pair<int, int>> GetPointFromArgs(
		WValue *args) {
		if (!args || webview_value_get_len(args) != 2) {
			return std::nullopt;
		}
		int x = int(webview_value_get_int(webview_value_get_list_value(args, 0)));
		int y = int(webview_value_get_int(webview_value_get_list_value(args, 1)));
		if (!x && !y) {
			return std::nullopt;
		}
		return std::make_pair(x, y);
	}

    void initCEFProcesses(CefMainArgs args){
		mainArgs = args;
	    CefExecuteProcess(mainArgs, app, nullptr);
    }

    void sendKeyEvent(CefKeyEvent& ev)
    {
        handler.get()->sendKeyEvent(ev);
    }

	void startCEF() {
		CefSettings cefs;
		cefs.windowless_rendering_enabled = true;
		cefs.no_sandbox = true;
		CefInitialize(mainArgs, cefs, app.get(), nullptr);
#if defined(OS_WIN)
		CefRunMessageLoop();
		CefShutdown();
#endif
	}

    void doMessageLoopWork()
    {
		CefDoMessageLoopWork();
    }

    int HandleMethodCall(std::string name, WValue* values, WValue* response) {
        int result = -1;
		if (name.compare("loadUrl") == 0) {
			if (const auto url = webview_value_get_string(values)) {
				handler.get()->loadUrl(url);
				result = 1;
			}
		}
		else if (name.compare("setSize") == 0) {
			const auto dpi = webview_value_get_double(webview_value_get_list_value(values, 0));
			const auto width = webview_value_get_double(webview_value_get_list_value(values, 1));
			const auto height = webview_value_get_double(webview_value_get_list_value(values, 2));
			handler.get()->changeSize((float)dpi, (int)std::round(width), (int)std::round(height));
			result = 1;
		}
		else if (name.compare("cursorClickDown") == 0) {
			const auto point = GetPointFromArgs(values);
			handler.get()->cursorClick(point->first, point->second, false);
			result = 1;
		}
		else if (name.compare("cursorClickUp") == 0) {
			const auto point = GetPointFromArgs(values);
			handler.get()->cursorClick(point->first, point->second, true);
			result = 1;
		}
		else if (name.compare("cursorMove") == 0) {
			const auto point = GetPointFromArgs(values);
			handler.get()->cursorMove(point->first, point->second, false);
			result = 1;
		}
		else if (name.compare("cursorDragging") == 0) {
			const auto point = GetPointFromArgs(values);
			handler.get()->cursorMove(point->first, point->second, true);
			result = 1;
		}
		else if (name.compare("setScrollDelta") == 0) {
			auto x = webview_value_get_int(webview_value_get_list_value(values, 0));
			auto y = webview_value_get_int(webview_value_get_list_value(values, 1));
			auto deltaX = webview_value_get_int(webview_value_get_list_value(values, 2));
			auto deltaY = webview_value_get_int(webview_value_get_list_value(values, 3));
			handler.get()->sendScrollEvent((int)x, (int)y, (int)deltaX, (int)deltaY);
			result = 1;
		}
		else if (name.compare("goForward") == 0) {
			handler.get()->goForward();
			result = 1;
		}
		else if (name.compare("goBack") == 0) {
			handler.get()->goBack();
			result = 1;
		}
		else if (name.compare("reload") == 0) {
			handler.get()->reload();
			result = 1;
		}
		else if (name.compare("openDevTools") == 0) {
			handler.get()->openDevTools();
			result = 1;
		}
		else if (name.compare("setClientFocus") == 0) {
			isFocused = webview_value_get_bool(webview_value_get_list_value(values, 0));
			result = 1;
		}
		else if(name.compare("setCookie") == 0){
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto key = webview_value_get_string(webview_value_get_list_value(values, 1));
			const auto value = webview_value_get_string(webview_value_get_list_value(values, 2));
			handler.get()->setCookie(domain, key, value);
			result = 1;	
		}
		else if (name.compare("deleteCookie") == 0) {
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto key = webview_value_get_string(webview_value_get_list_value(values, 1));
			handler.get()->deleteCookie(domain, key);
			result = 1;	
		}
		else if (name.compare("visitAllCookies") == 0) {
			handler.get()->visitAllCookies();
			result = 1;	
		}
		else if (name.compare("visitUrlCookies") == 0) {
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto isHttpOnly = webview_value_get_bool(webview_value_get_list_value(values, 1));
			handler.get()->visitUrlCookies(domain, isHttpOnly);
			result = 1;	
		}
		else if(name.compare("setJavaScriptChannels") == 0){
			auto len = webview_value_get_len(values);
			std::vector<std::string> channels;
			for(size_t i = 0; i < len; i++){
				auto channel = webview_value_get_string(webview_value_get_list_value(values, i));
				channels.push_back(channel);
			}
			handler.get()->setJavaScriptChannels(channels);
			result = 1;	
		}
		else if (name.compare("sendJavaScriptChannelCallBack") == 0) {
			const auto error = webview_value_get_bool(webview_value_get_list_value(values, 0));
			const auto ret = webview_value_get_string(webview_value_get_list_value(values, 1));
			const auto callbackId = webview_value_get_string(webview_value_get_list_value(values, 2));
			const auto frameId = webview_value_get_string(webview_value_get_list_value(values, 3));
			handler.get()->sendJavaScriptChannelCallBack(error, ret,callbackId,frameId);
			result = 1;	
		}
		else if(name.compare("executeJavaScript") == 0){
			const auto code = webview_value_get_string(webview_value_get_list_value(values, 0));
			handler.get()->executeJavaScript(code);
			result = 1;	
		}
		else {
			result = 0;
		}
		if(response == nullptr){
			response = webview_value_new_null();
		}
        return result;
	}

	void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height) {
		int32_t* dest = (int32_t*)_dest;
		int32_t* src = (int32_t*)_src;
		int32_t rgba;
		int32_t bgra;
		int length = width * height;
		for (int i = 0; i < length; i++) {
			bgra = src[i];
			// BGRA in hex = 0xAARRGGBB.
			rgba = (bgra & 0x00ff0000) >> 16 // Red >> Blue.
				| (bgra & 0xff00ff00) // Green Alpha.
				| (bgra & 0x000000ff) << 16; // Blue >> Red.
			dest[i] = rgba;
		}
	}

	void setPaintCallBack(std::function<void(const void *, int32_t, int32_t)> callback)	{
		if (!init)
		{
			handler.get()->onPaintCallback = callback;
			handler.get()->onUrlChangedCb = [](std::string url)
			{
				if (invokeFunc)
				{
					invokeFunc("urlChanged", webview_value_new_string(const_cast<char *>(url.c_str())));
				}
			};

			handler.get()->onTitleChangedCb = [](std::string title)
			{
				if (invokeFunc)
				{
					invokeFunc("titleChanged", webview_value_new_string(const_cast<char *>(title.c_str())));
				}
			};

			handler.get()->onAllCookieVisitedCb = [](std::map<std::string, std::map<std::string, std::string>> cookies)
			{
				if (invokeFunc)
				{
					WValue* retMap = webview_value_new_map();
					for (auto &cookie : cookies)
					{
						WValue* tempMap = webview_value_new_map();
						for (auto &c : cookie.second)
						{
							webview_value_set_string(tempMap, c.first.c_str(), webview_value_new_string(const_cast<char *>(c.second.c_str())));
						}
						webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
					}
					invokeFunc("allCookiesVisited", retMap);
					webview_value_unref(retMap);
				}
			};

			handler.get()->onUrlCookieVisitedCb = [](std::map<std::string, std::map<std::string, std::string>> cookies)
			{
				if (invokeFunc)
				{
					WValue* retMap = webview_value_new_map();
					for (auto &cookie : cookies)
					{
						WValue* tempMap = webview_value_new_map();
						for (auto &c : cookie.second)
						{
							webview_value_set_string(tempMap, c.first.c_str(), webview_value_new_string(const_cast<char *>(c.second.c_str())));
						}
						webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
					}
					invokeFunc("urlCookiesVisited", retMap);
					webview_value_unref(retMap);
				}
			};

			handler.get()->onJavaScriptChannelMessage = [](std::string channelName, std::string message, std::string callbackId, std::string frameId)
			{
				if (invokeFunc)
				{
					WValue* retMap = webview_value_new_map();
					webview_value_set_string(retMap, "channel", webview_value_new_string(const_cast<char *>(channelName.c_str())));
					webview_value_set_string(retMap, "message", webview_value_new_string(const_cast<char *>(message.c_str())));
					webview_value_set_string(retMap, "callbackId", webview_value_new_string(const_cast<char *>(callbackId.c_str())));
					webview_value_set_string(retMap, "frameId", webview_value_new_string(const_cast<char *>(frameId.c_str())));
					invokeFunc("javascriptChannelMessage", retMap);
					webview_value_unref(retMap);
				}
			};

#if defined(OS_WIN)
			//windows run in multi thread
			new std::thread(startCEF);
#else
			//mac、linux run in main thread 
			startCEF();
#endif
			init = true;
		}
    }

	void setInvokeMethodFunc(std::function<void(std::string, WValue*)> func){
		invokeFunc = func;
	}

	bool getPluginIsFocused() {
		return isFocused;
	}
}