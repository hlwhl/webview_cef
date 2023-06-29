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
	std::function<void(std::string, PluginValue*)> invokeFunc;
    
    CefRefPtr<WebviewHandler> handler(new WebviewHandler());
    CefRefPtr<WebviewApp> app(new WebviewApp(handler));
    CefMainArgs mainArgs;

	static const std::optional<std::pair<int, int>> GetPointFromArgs(
		const PluginValue *args) {
		const PluginValueList* list = std::get_if<PluginValueList>(args);
		if (!list || list->size() != 2) {
			return std::nullopt;
		}
		auto x = (*list)[0].LongValue();
		auto y = (*list)[1].LongValue();
		if (!x && !y) {
			return std::nullopt;
		}
		return std::make_pair((int)x, (int)y);
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
		handler.get()->onUrlChangedCb = [](std::string url) {
			if(invokeFunc){
				invokeFunc("urlChanged", new PluginValue(url));
			}
		};

		handler.get()->onTitleChangedCb = [](std::string title) {
			if(invokeFunc){
				invokeFunc("titleChanged", new PluginValue(title));
			}
		};

		handler.get()->onAllCookieVisitedCb = [](std::map<std::string, std::map<std::string, std::string>> cookies) {
			if(invokeFunc){
				PluginValueMap retMap;
				for (auto& cookie : cookies)
				{
					PluginValueMap tempMap;
					for (auto& c : cookie.second)
					{
						tempMap[PluginValue(c.first)] = PluginValue(c.second);
					}
					retMap[PluginValue(cookie.first)] = PluginValue(tempMap);
				}
				invokeFunc("allCookiesVisited", new PluginValue(retMap));
			}
		};

		handler.get()->onUrlCookieVisitedCb = [](std::map<std::string, std::map<std::string, std::string>> cookies) {
			if(invokeFunc){
				PluginValueMap retMap;
				for (auto& cookie : cookies)
				{
					PluginValueMap tempMap;
					for (auto& c : cookie.second)
					{
						tempMap[PluginValue(c.first)] = PluginValue(c.second);
					}
					retMap[PluginValue(cookie.first)] = PluginValue(tempMap);
				}
				invokeFunc("urlCookiesVisited", new PluginValue(retMap));
			}
		};

		handler.get()->onJavaScriptChannelMessage = [](std::string channelName, std::string message, std::string callbackId, std::string frameId) {
			if(invokeFunc){
				PluginValueMap retMap;
				retMap[PluginValue("channel")] = PluginValue(channelName);
				retMap[PluginValue("message")] = PluginValue(message);
				retMap[PluginValue("callbackId")] = PluginValue(callbackId);
				retMap[PluginValue("frameId")] = PluginValue(frameId);
				invokeFunc("javascriptChannelMessage", new PluginValue(retMap));
			}
		};

		handler.get()->onFocusedNodeChangeMessage = [](bool editable) {
			if(invokeFunc){
				invokeFunc("onFocusedNodeChangeMessage", new PluginValue(editable));
			}
		};

		handler.get()->onImeCompositionRangeChangedMessage = [](int32_t x, int32_t y) {
			if(invokeFunc){
				PluginValueMap retMap;
				retMap[PluginValue("x")] = PluginValue(x);
				retMap[PluginValue("y")] = PluginValue(y);
				invokeFunc("onImeCompositionRangeChangedMessage", new PluginValue(retMap));
			}
		};

		CefSettings cefs;
		cefs.windowless_rendering_enabled = true;
		cefs.no_sandbox = true;
		CefInitialize(mainArgs, cefs, app.get(), nullptr);
		CefRunMessageLoop();
		CefShutdown();
	}

	int HandleMethodCall(std::string name, PluginValue* values, PluginValue* response) {
        int result = -1;
		if (name.compare("loadUrl") == 0) {
			if (const auto url = std::get_if<std::string>(values)) {
				handler.get()->loadUrl(*url);
				result = 1;
			}
		}
		else if (name.compare("setSize") == 0) {
            const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto dpi = *std::get_if<double>(&(*list)[0]);
			const auto width = *std::get_if<double>(&(*list)[1]);
			const auto height = *std::get_if<double>(&(*list)[2]);
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
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			auto x = (*list)[0].LongValue();
			auto y = (*list)[1].LongValue();
			auto deltaX = (*list)[2].LongValue();
			auto deltaY = (*list)[3].LongValue();
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
		else if (name.compare("imeSetComposition") == 0) {
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto text = *std::get_if<std::string>(&(*list)[0]);
			handler.get()->imeSetComposition(text);
			result = 1;
		} 
		else if (name.compare("imeCommitText") == 0) {
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto text = *std::get_if<std::string>(&(*list)[0]);
			handler.get()->imeCommitText(text);
			result = 1;
		} 
		else if (name.compare("setClientFocus") == 0) {
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto focus = *std::get_if<bool>(&(*list)[0]);
			handler.get()->setClientFocus(focus);
			result = 1;
		}
		else if(name.compare("setCookie") == 0){
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto domain = *std::get_if<std::string>(&(*list)[0]);
			const auto key = *std::get_if<std::string>(&(*list)[1]);
			const auto value = *std::get_if<std::string>(&(*list)[2]);
			handler.get()->setCookie(domain, key, value);
			result = 1;	
		}
		else if (name.compare("deleteCookie") == 0) {
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto domain = *std::get_if<std::string>(&(*list)[0]);
			const auto key = *std::get_if<std::string>(&(*list)[1]);
			handler.get()->deleteCookie(domain, key);
			result = 1;	
		}
		else if (name.compare("visitAllCookies") == 0) {
			handler.get()->visitAllCookies();
			result = 1;	
		}
		else if (name.compare("visitUrlCookies") == 0) {
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto domain = *std::get_if<std::string>(&(*list)[0]);
			const auto isHttpOnly = *std::get_if<bool>(&(*list)[1]);
			handler.get()->visitUrlCookies(domain, isHttpOnly);
			result = 1;	
		}
		else if(name.compare("setJavaScriptChannels") == 0){
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto jsChannels = *std::get_if<PluginValueList>(&(*list)[0]);
			std::vector<std::string> channels;
			for (auto& jsChannel : jsChannels) {
				channels.push_back(*std::get_if<std::string>(&(jsChannel)));
			}
			handler.get()->setJavaScriptChannels(channels);
			result = 1;	
		}
		else if (name.compare("sendJavaScriptChannelCallBack") == 0) {
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto error = *std::get_if<bool>(&(*list)[0]);
			const auto ret = *std::get_if<std::string>(&(*list)[1]);
			const auto callbackId = *std::get_if<std::string>(&(*list)[2]);
			const auto frameId = *std::get_if<std::string>(&(*list)[3]);
			handler.get()->sendJavaScriptChannelCallBack(error, ret,callbackId,frameId);
			result = 1;	
		}
		else if(name.compare("executeJavaScript") == 0){
			const PluginValueList* list = std::get_if<PluginValueList>(values);
			const auto code = *std::get_if<std::string>(&(*list)[0]);
			handler.get()->executeJavaScript(code);
			result = 1;	
		}
		else {
			result = 0;
		}
		if(response == nullptr){
			response = new PluginValue(nullptr);
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

    void setPaintCallBack(std::function<void(const void*, int32_t , int32_t )> callback)
    {
		if(!init){
		handler.get()->onPaintCallback = callback;
		new std::thread(startCEF);
			init = true;
		}
    }

	void setInvokeMethodFunc(std::function<void(std::string, PluginValue*)> func){
		invokeFunc = func;
	}

}