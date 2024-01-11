#include "webview_plugin.h"
#include "webview_app.h"

#ifdef OS_MAC
#include <include/wrapper/cef_library_loader.h>
#endif

#include <math.h>
#include <memory>
#include <thread>
#include <iostream>
// #include <mutex>

namespace webview_cef {
	bool init = false;
	bool isFocused = false;
	std::function<void(std::string, WValue*)> invokeFunc;
    
    CefRefPtr<WebviewHandler> handler;
    CefRefPtr<WebviewApp> app;
    CefMainArgs mainArgs;

	static int cursorAction(WValue *args, std::string name) {
		if (!args || webview_value_get_len(args) != 2) {
			return 0;
		}
		int x = int(webview_value_get_int(webview_value_get_list_value(args, 0)));
		int y = int(webview_value_get_int(webview_value_get_list_value(args, 1)));
		if (!x && !y) {
			return 0;
		}
		if (name.compare("cursorClickDown") == 0) {
			handler.get()->cursorClick(x, y, false);
		}
		else if (name.compare("cursorClickUp") == 0) {
			handler.get()->cursorClick(x, y, true);
		}
		else if (name.compare("cursorMove") == 0) {
			handler.get()->cursorMove(x, y, false);
		}
		else if (name.compare("cursorDragging") == 0) {
			handler.get()->cursorMove(x, y, true);
		}
		return 1;
	}

    void initCEFProcesses(CefMainArgs args){
		mainArgs = args;
	    initCEFProcesses();
    }

	void initCEFProcesses(){
#ifdef OS_MAC
		CefScopedLibraryLoader loader;
    	if(!loader.LoadInMain()) {
        	printf("load cef err");
    	}
#endif
    	handler = new WebviewHandler();
    	app = new WebviewApp(handler);
		CefExecuteProcess(mainArgs, app, nullptr);
	}

    void sendKeyEvent(CefKeyEvent& ev)
    {
        handler.get()->sendKeyEvent(ev);
    }

	void startCEF() {
		CefSettings cefs;
		cefs.windowless_rendering_enabled = true;
#ifndef OS_MAC
		cefs.no_sandbox = true;
#endif

#ifdef OS_WIN
		//cef message loop run in another thread on windows
		cefs.multi_threaded_message_loop = true;
#else
		//cef message loop handle by MainApplication
		cefs.external_message_pump = true;
    	//CefString(&cefs.browser_subprocess_path) = "/Library/Chaches"; //the helper Program path
#endif

		CefInitialize(mainArgs, cefs, app.get(), nullptr);
	}

    void doMessageLoopWork()
    {
		CefDoMessageLoopWork();
    }

    void HandleMethodCall(std::string name, WValue* values, std::function<void(int ,WValue*)> result) {
		if(name.compare("dispose") == 0){
			// we don't need to dispose the texture, texture will be disposed by flutter engine
			CefShutdown();
			result(1, nullptr);
		}
		else if (name.compare("loadUrl") == 0) {
			if (const auto url = webview_value_get_string(values)) {
				handler.get()->loadUrl(url);
				result(1, nullptr);
			}
		}
		else if (name.compare("setSize") == 0) {
			const auto dpi = webview_value_get_double(webview_value_get_list_value(values, 0));
			const auto width = webview_value_get_double(webview_value_get_list_value(values, 1));
			const auto height = webview_value_get_double(webview_value_get_list_value(values, 2));
			handler.get()->changeSize((float)dpi, (int)std::round(width), (int)std::round(height));
			result(1, nullptr);
		}
		else if (name.compare("cursorClickDown") == 0 
			|| name.compare("cursorClickUp") == 0 
			|| name.compare("cursorMove") == 0 
			|| name.compare("cursorDragging") == 0) {
			result(cursorAction(values, name), nullptr);
		}
		else if (name.compare("setScrollDelta") == 0) {
			auto x = webview_value_get_int(webview_value_get_list_value(values, 0));
			auto y = webview_value_get_int(webview_value_get_list_value(values, 1));
			auto deltaX = webview_value_get_int(webview_value_get_list_value(values, 2));
			auto deltaY = webview_value_get_int(webview_value_get_list_value(values, 3));
			handler.get()->sendScrollEvent((int)x, (int)y, (int)deltaX, (int)deltaY);
			result(1, nullptr);
		}
		else if (name.compare("goForward") == 0) {
			handler.get()->goForward();
			result(1, nullptr);
		}
		else if (name.compare("goBack") == 0) {
			handler.get()->goBack();
			result(1, nullptr);
		}
		else if (name.compare("reload") == 0) {
			handler.get()->reload();
			result(1, nullptr);
		}
		else if (name.compare("openDevTools") == 0) {
			handler.get()->openDevTools();
			result(1, nullptr);
		}
		else if (name.compare("setClientFocus") == 0) {
			isFocused = webview_value_get_bool(webview_value_get_list_value(values, 0));
			result(1, nullptr);
		}
		else if(name.compare("setCookie") == 0){
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto key = webview_value_get_string(webview_value_get_list_value(values, 1));
			const auto value = webview_value_get_string(webview_value_get_list_value(values, 2));
			handler.get()->setCookie(domain, key, value);
			result(1, nullptr);
		}
		else if (name.compare("deleteCookie") == 0) {
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto key = webview_value_get_string(webview_value_get_list_value(values, 1));
			handler.get()->deleteCookie(domain, key);
			result(1, nullptr);
		}
		else if (name.compare("visitAllCookies") == 0) {
			handler.get()->visitAllCookies([=](std::map<std::string, std::map<std::string, std::string>> cookies){
				WValue* retMap = webview_value_new_map();
				for (auto &cookie : cookies)
				{
					WValue* tempMap = webview_value_new_map();
					for (auto &c : cookie.second)
					{
						WValue * val = webview_value_new_string(const_cast<char *>(c.second.c_str()));
						webview_value_set_string(tempMap, c.first.c_str(), val);
						webview_value_unref(val);
					}
					webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
					webview_value_unref(tempMap);
				}
				result(1, retMap);	
				webview_value_unref(retMap);
			});
		}
		else if (name.compare("visitUrlCookies") == 0) {
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto isHttpOnly = webview_value_get_bool(webview_value_get_list_value(values, 1));
			handler.get()->visitUrlCookies(domain, isHttpOnly,[=](std::map<std::string, std::map<std::string, std::string>> cookies){
				WValue* retMap = webview_value_new_map();
				for (auto &cookie : cookies)
				{
					WValue* tempMap = webview_value_new_map();
					for (auto &c : cookie.second)
					{
						WValue * val = webview_value_new_string(const_cast<char *>(c.second.c_str()));
						webview_value_set_string(tempMap, c.first.c_str(), val);
						webview_value_unref(val);
					}
					webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
					webview_value_unref(tempMap);
				}
				result(1, retMap);	
				webview_value_unref(retMap);
			});
		}
		else if(name.compare("setJavaScriptChannels") == 0){
			auto len = webview_value_get_len(values);
			std::vector<std::string> channels;
			for(size_t i = 0; i < len; i++){
				auto channel = webview_value_get_string(webview_value_get_list_value(values, i));
				channels.push_back(channel);
			}
			handler.get()->setJavaScriptChannels(channels);
			result(1, nullptr);
		}
		else if (name.compare("sendJavaScriptChannelCallBack") == 0) {
			const auto error = webview_value_get_bool(webview_value_get_list_value(values, 0));
			const auto ret = webview_value_get_string(webview_value_get_list_value(values, 1));
			const auto callbackId = webview_value_get_string(webview_value_get_list_value(values, 2));
			const auto frameId = webview_value_get_string(webview_value_get_list_value(values, 3));
			handler.get()->sendJavaScriptChannelCallBack(error, ret,callbackId,frameId);
			result(1, nullptr);
		}
		else if(name.compare("executeJavaScript") == 0){
			const auto code = webview_value_get_string(webview_value_get_list_value(values, 0));
			handler.get()->executeJavaScript(code);
			result(1, nullptr);
		}
		else {
			result = 0;
		}
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
			handler.get()->onUrlChangedEvent = [](std::string url)
			{
				if (invokeFunc)
				{
					WValue *wUrl = webview_value_new_string(const_cast<char *>(url.c_str()));
					invokeFunc("onUrlChangedEvent", wUrl);
					webview_value_unref(wUrl);
				}
			};

			handler.get()->onTitleChangedEvent = [](std::string title)
			{
				if (invokeFunc)
				{
					WValue *wTitle = webview_value_new_string(const_cast<char *>(title.c_str()));
					invokeFunc("onTitleChangedEvent", wTitle);
					webview_value_unref(wTitle);
				}
			};

			handler.get()->onTooltipEvent = [](std::string text) {
				if (invokeFunc) {
					WValue* wText = webview_value_new_string(const_cast<char*>(text.c_str()));
					WValue* retMap = webview_value_new_map();
					webview_value_set_string(retMap, "text", wText);
					invokeFunc("onTooltipEvent", retMap);
					webview_value_unref(wText);
					webview_value_unref(retMap);
				}
			};

			handler.get()->onCursorChangedEvent = [](int type) {
				if(invokeFunc){
					WValue* wType = webview_value_new_int(type);
					WValue* retMap = webview_value_new_map();
					webview_value_set_string(retMap, "type", wType);
					invokeFunc("onCursorChangedEvent", retMap);
					webview_value_unref(wType);
					webview_value_unref(retMap);
				}
			};

			handler.get()->onConsoleMessageEvent = [](int level, std::string message, std::string source, int line){
				if(invokeFunc){
					WValue* wLevel = webview_value_new_int(level);
					WValue* wMessage = webview_value_new_string(const_cast<char*>(message.c_str()));
					WValue* wSource = webview_value_new_string(const_cast<char*>(source.c_str()));
					WValue* wLine = webview_value_new_int(line);
					WValue* retMap = webview_value_new_map();
					webview_value_set_string(retMap, "level", wLevel);
					webview_value_set_string(retMap, "message", wMessage);
					webview_value_set_string(retMap, "source", wSource);
					webview_value_set_string(retMap, "line", wLine);
					invokeFunc("onConsoleMessageEvent", retMap);
					webview_value_unref(wLevel);
					webview_value_unref(wMessage);
					webview_value_unref(wSource);
					webview_value_unref(wLine);
					webview_value_unref(retMap);
				}
			};

			handler.get()->onJavaScriptChannelMessage = [](std::string channelName, std::string message, std::string callbackId, std::string frameId)
			{
				if (invokeFunc)
				{
					WValue* retMap = webview_value_new_map();
					WValue* channel = webview_value_new_string(const_cast<char *>(channelName.c_str()));
					WValue* msg = webview_value_new_string(const_cast<char *>(message.c_str()));
					WValue* cbId = webview_value_new_string(const_cast<char *>(callbackId.c_str()));
					WValue* fId = webview_value_new_string(const_cast<char *>(frameId.c_str()));
					webview_value_set_string(retMap, "channel", channel);
					webview_value_set_string(retMap, "message", msg);
					webview_value_set_string(retMap, "callbackId", cbId);
					webview_value_set_string(retMap, "frameId", fId);
					invokeFunc("javascriptChannelMessage", retMap);
					webview_value_unref(retMap);
					webview_value_unref(channel);
					webview_value_unref(msg);
					webview_value_unref(cbId);
					webview_value_unref(fId);
				}
			};
			startCEF();
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
