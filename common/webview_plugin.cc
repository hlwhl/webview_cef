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
		const auto x = std::get_if<int64_t>(&(*list)[0]);
		const auto y = std::get_if<int64_t>(&(*list)[1]);
		if (!x || !y) {
			return std::nullopt;
		}
		return std::make_pair(*x, *y);
	}

    void initCEFProcesses(CefMainArgs args){
		mainArgs = args;
	    CefExecuteProcess(mainArgs, app, nullptr);
    }

    void sendKeyEvent(CefKeyEvent ev)
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
			const auto x = *std::get_if<int64_t>(&(*list)[0]);
			const auto y = *std::get_if<int64_t>(&(*list)[1]);
			const auto deltaX = *std::get_if<int64_t>(&(*list)[2]);
			const auto deltaY = *std::get_if<int64_t>(&(*list)[3]);
			handler.get()->sendScrollEvent(x, y, deltaX, deltaY);
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
		handler.get()->onPaintCallback = callback;
		new std::thread(startCEF);
    }

	void setInvokeMethodFunc(std::function<void(std::string, PluginValue*)> func){
		invokeFunc = func;
	}

}