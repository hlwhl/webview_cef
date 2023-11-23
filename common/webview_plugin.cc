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
    
    CefRefPtr<WebviewHandler> handler(new WebviewHandler());
    CefRefPtr<WebviewApp> app(new WebviewApp(handler));
    CefMainArgs mainArgs;
	CefString globalUserAgent;

	static int cursorAction(WValue *args, std::string name) {
		if (!args || webview_value_get_len(args) != 3) {
			return 0;
		}
		int browserId = int(webview_value_get_int(webview_value_get_list_value(args, 0)));
		int x = int(webview_value_get_int(webview_value_get_list_value(args, 1)));
		int y = int(webview_value_get_int(webview_value_get_list_value(args, 2)));
		if (!x && !y) {
			return 0;
		}
		if (name.compare("cursorClickDown") == 0) {
			handler.get()->cursorClick(browserId, x, y, false);
		}
		else if (name.compare("cursorClickUp") == 0) {
			handler.get()->cursorClick(browserId, x, y, true);
		}
		else if (name.compare("cursorMove") == 0) {
			handler.get()->cursorMove(browserId, x, y, false);
		}
		else if (name.compare("cursorDragging") == 0) {
			handler.get()->cursorMove(browserId, x, y, true);
		}
		return 1;
	}

    void initCEFProcesses(CefMainArgs args){
		mainArgs = args;
	    CefExecuteProcess(mainArgs, app, nullptr);
    }

	void initCEFProcesses(){
#ifdef OS_MAC
		CefScopedLibraryLoader loader;
    	if(!loader.LoadInMain()) {
        	printf("load cef err");
    	}
#endif
		CefExecuteProcess(mainArgs, app, nullptr);
	}

    void sendKeyEvent(CefKeyEvent& ev)
    {
		if(isFocused){
	        handler.get()->sendKeyEvent(ev);
		}
    }

    void createBrowser(int64_t textureId, int browserId)
    {
		// Specify CEF browser settings here.
		CefBrowserSettings browser_settings;
		browser_settings.windowless_frame_rate = 60;
				
		CefWindowInfo window_info;
		window_info.SetAsWindowless(0);

		// create browser
		CefBrowserHost::CreateBrowser(window_info, handler, "", browser_settings, nullptr, nullptr);
		handler->setBrowserId(textureId, browserId);
    }

	void closeBrowser(int browserId)
    {
		handler->closeBrowser(browserId);
    }

	void closeAllBrowser(){
		handler->CloseAllBrowsers(true);
	}

    void startCEF()
    {
        CefSettings cefs;
		cefs.windowless_rendering_enabled = true;       
#ifdef OS_MAC
		cefs.external_message_pump = true;
    	//CefString(&cefs.browser_subprocess_path) = "/Library/Chaches";
#else
		cefs.no_sandbox = true;
#endif
		CefInitialize(mainArgs, cefs, app.get(), nullptr);

#ifdef OS_WIN
		CefRunMessageLoop();
		CefShutdown();
#endif
    }

    void doMessageLoopWork(){
		CefDoMessageLoopWork();
    }

    int HandleMethodCall(std::string name, WValue* values, WValue* response) {
        int result = -1;
		if (name.compare("loadUrl") == 0) {
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto url = webview_value_get_string(webview_value_get_list_value(values, 1));
			if(url != nullptr){
				handler.get()->loadUrl(browserId, url);
				result = 1;			
			}
		}
		else if (name.compare("setSize") == 0) {
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto dpi = webview_value_get_double(webview_value_get_list_value(values, 1));
			const auto width = webview_value_get_double(webview_value_get_list_value(values, 2));
			const auto height = webview_value_get_double(webview_value_get_list_value(values, 3));
			handler.get()->changeSize(browserId, (float)dpi, (int)std::round(width), (int)std::round(height));
			result = 1;
		}
		else if (name.compare("cursorClickDown") == 0 
			|| name.compare("cursorClickUp") == 0 
			|| name.compare("cursorMove") == 0 
			|| name.compare("cursorDragging") == 0) {
			result = cursorAction(values, name);
		}
		else if (name.compare("setScrollDelta") == 0) {
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			auto x = webview_value_get_int(webview_value_get_list_value(values, 1));
			auto y = webview_value_get_int(webview_value_get_list_value(values, 2));
			auto deltaX = webview_value_get_int(webview_value_get_list_value(values, 3));
			auto deltaY = webview_value_get_int(webview_value_get_list_value(values, 4));
			handler.get()->sendScrollEvent(browserId, (int)x, (int)y, (int)deltaX, (int)deltaY);
			result = 1;
		}
		else if (name.compare("goForward") == 0) {
			int browserId = int(webview_value_get_int(values));
			handler.get()->goForward(browserId);
			result = 1;
		}
		else if (name.compare("goBack") == 0) {
			int browserId = int(webview_value_get_int(values));
			handler.get()->goBack(browserId);
			result = 1;
		}
		else if (name.compare("reload") == 0) {
			int browserId = int(webview_value_get_int(values));
			handler.get()->reload(browserId);
			result = 1;
		}
		else if (name.compare("openDevTools") == 0) {			
			int browserId = int(webview_value_get_int(values));
			handler.get()->openDevTools(browserId);
			result = 1;
		}
		else if (name.compare("imeSetComposition") == 0) {
			std::string text = webview_value_get_string(values);
			handler.get()->imeSetComposition(text);
			result = 1;
		} 
		else if (name.compare("imeCommitText") == 0) {
			std::string text = webview_value_get_string(values);
			handler.get()->imeCommitText(text);
			result = 1;
		} 
		else if (name.compare("setClientFocus") == 0) {
			isFocused = webview_value_get_bool(webview_value_get_list_value(values, 0));
			handler.get()->setClientFocus(isFocused);
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
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			WValue *list = webview_value_get_list_value(values, 1);
			auto len = webview_value_get_len(list);
			std::vector<std::string> channels;
			for(size_t i = 0; i < len; i++){
				auto channel = webview_value_get_string(webview_value_get_list_value(list, i));
				channels.push_back(channel);
			}
			handler.get()->setJavaScriptChannels(browserId, channels);
			result = 1;	
		}
		else if (name.compare("sendJavaScriptChannelCallBack") == 0) {
			const auto error = webview_value_get_bool(webview_value_get_list_value(values, 0));
			const auto ret = webview_value_get_string(webview_value_get_list_value(values, 1));
			const auto callbackId = webview_value_get_string(webview_value_get_list_value(values, 2));
			const auto browserId = int(webview_value_get_int(webview_value_get_list_value(values, 3)));
			const auto frameId = webview_value_get_string(webview_value_get_list_value(values, 4));
			handler.get()->sendJavaScriptChannelCallBack(error, ret, callbackId, browserId, frameId);
			result = 1;	
		}
		else if(name.compare("executeJavaScript") == 0){
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto code = webview_value_get_string(webview_value_get_list_value(values, 1));
			handler.get()->executeJavaScript(browserId, code);
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

	void setUserAgent(WValue* userAgent){
		globalUserAgent = CefString(webview_value_get_string(userAgent));
	}

	void setPaintCallBack(std::function<void(int64_t textureId, const void *, int32_t, int32_t)> callback)	{
		if (!init)
		{
			handler.get()->onPaintCallback = callback;
			handler.get()->onUrlChangedCb = [](std::string url)
			{
				if (invokeFunc)
				{
					WValue *wUrl = webview_value_new_string(const_cast<char *>(url.c_str()));
					invokeFunc("urlChanged", wUrl);
					webview_value_unref(wUrl);
				}
			};

			handler.get()->onTitleChangedCb = [](std::string title)
			{
				if (invokeFunc)
				{
					WValue *wTitle = webview_value_new_string(const_cast<char *>(title.c_str()));
					invokeFunc("titleChanged", wTitle);
					webview_value_unref(wTitle);
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
							WValue * val = webview_value_new_string(const_cast<char *>(c.second.c_str()));
							webview_value_set_string(tempMap, c.first.c_str(), val);
							webview_value_unref(val);
						}
						webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
						webview_value_unref(tempMap);
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
							WValue * val = webview_value_new_string(const_cast<char *>(c.second.c_str()));
							webview_value_set_string(tempMap, c.first.c_str(), val);
							webview_value_unref(val);
						}
						webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
						webview_value_unref(tempMap);
					}
					invokeFunc("urlCookiesVisited", retMap);
					webview_value_unref(retMap);
				}
			};

			handler.get()->onJavaScriptChannelMessage = [](std::string channelName, std::string message, std::string callbackId, int browserId, std::string frameId)
			{
				if (invokeFunc)
				{
					WValue* retMap = webview_value_new_map();
					WValue* channel = webview_value_new_string(const_cast<char *>(channelName.c_str()));
					WValue* msg = webview_value_new_string(const_cast<char *>(message.c_str()));
					WValue* cbId = webview_value_new_string(const_cast<char *>(callbackId.c_str()));
					WValue* bId = webview_value_new_int(browserId);
					WValue* fId = webview_value_new_string(const_cast<char *>(frameId.c_str()));
					webview_value_set_string(retMap, "channel", channel);
					webview_value_set_string(retMap, "message", msg);
					webview_value_set_string(retMap, "callbackId", cbId);
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "frameId", fId);
					invokeFunc("javascriptChannelMessage", retMap);
					webview_value_unref(retMap);
					webview_value_unref(channel);
					webview_value_unref(msg);
					webview_value_unref(cbId);
					webview_value_unref(bId);
					webview_value_unref(fId);
				}
			};
      
			handler.get()->onFocusedNodeChangeMessage = [](bool editable)
			{
				if (invokeFunc)
				{
					WValue* value = webview_value_new_bool(editable);
					invokeFunc("onFocusedNodeChangeMessage", value);
					webview_value_unref(value);
				}
			};

			handler.get()->onImeCompositionRangeChangedMessage = [](int32_t x, int32_t y)
			{
				if (invokeFunc)
				{
					WValue *retMap = webview_value_new_map();
					WValue *xValue = webview_value_new_int(x);
					WValue *yValue = webview_value_new_int(y);
					webview_value_set_string(retMap, "x", xValue);
					webview_value_set_string(retMap, "y", yValue);
					invokeFunc("onImeCompositionRangeChangedMessage", retMap);
					webview_value_unref(xValue);
					webview_value_unref(yValue);
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
