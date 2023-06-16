#include "webview_plugin.h"

#include "webview_app.h"

#include <math.h>
#include <memory>
#include <thread>
#include <iostream>
#include <mutex>

namespace webview_cef {
	bool init = false;
	int64_t texture_id;
// 	std::unique_ptr<uint8_t> backing_pixel_buffer;
// 	std::mutex buffer_mutex_;
    
    CefRefPtr<WebviewHandler> handler(new WebviewHandler());
    CefRefPtr<WebviewApp> app(new WebviewApp(handler));
    CefMainArgs mainArgs;

// 	void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height) {
// 		int32_t* dest = (int32_t*)_dest;
// 		int32_t* src = (int32_t*)_src;
// 		int32_t rgba;
// 		int32_t bgra;
// 		int length = width * height;
// 		for (int i = 0; i < length; i++) {
// 			bgra = src[i];
// 			// BGRA in hex = 0xAARRGGBB.
// 			rgba = (bgra & 0x00ff0000) >> 16 // Red >> Blue.
// 				| (bgra & 0xff00ff00) // Green Alpha.
// 				| (bgra & 0x000000ff) << 16; // Blue >> Red.
// 			dest[i] = rgba;
// 		}
// 	}

//     	template <typename T>
// 	std::optional<T> GetOptionalValue(const flutter::EncodableMap& map,
// 		const std::string& key) {
// 		const auto it = map.find(flutter::EncodableValue(key));
// 		if (it != map.end()) {
// 			const auto val = std::get_if<T>(&it->second);
// 			if (val) {
// 				return *val;
// 			}
// 		}
// 		return std::nullopt;
// 	}

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
		CefWindowInfo window_info;
		CefBrowserSettings settings;
		window_info.SetAsWindowless(0);

		// handler.get()->onPaintCallback = [](const void* buffer, int32_t width, int32_t height) {
		// 	const std::lock_guard<std::mutex> lock(buffer_mutex_);
		// 	if (!pixel_buffer.get() || pixel_buffer.get()->width != width || pixel_buffer.get()->height != height) {
		// 		if (!pixel_buffer.get()) {
		// 			pixel_buffer = std::make_unique<FlutterDesktopPixelBuffer>();
		// 			pixel_buffer->release_context = &buffer_mutex_;
		// 			// Gets invoked after the FlutterDesktopPixelBuffer's
		// 			// backing buffer has been uploaded.
		// 			pixel_buffer->release_callback = [](void* opaque) {
		// 				auto mutex = reinterpret_cast<std::mutex*>(opaque);
		// 				// Gets locked just before |CopyPixelBuffer| returns.
		// 				mutex->unlock();
		// 			};
		// 		}
		// 		pixel_buffer->width = width;
		// 		pixel_buffer->height = height;
		// 		const auto size = width * height * 4;
		// 		backing_pixel_buffer.reset(new uint8_t[size]);
		// 		pixel_buffer->buffer = backing_pixel_buffer.get();
		// 	}

		// 	SwapBufferFromBgraToRgba((void*)pixel_buffer->buffer, buffer, width, height);
		// 	texture_registrar->MarkTextureFrameAvailable(texture_id);
		// };

		// handler.get()->onUrlChangedCb = [](std::string url) {
		// 	channel->InvokeMethod("urlChanged", std::make_unique<flutter::EncodableValue>(url));
		// };

		// handler.get()->onTitleChangedCb = [](std::string title) {
		// 	channel->InvokeMethod("titleChanged", std::make_unique<flutter::EncodableValue>(title));
		// };

		CefSettings cefs;
		cefs.windowless_rendering_enabled = true;
		cefs.no_sandbox = true;
		CefInitialize(mainArgs, cefs, app.get(), nullptr);
		CefRunMessageLoop();
		CefShutdown();
	}

	int HandleMethodCall(std::string name, PluginValue* values, PluginValue* response) {
        int result = -1;
        if(name.compare("init") == 0)
        {
            if(!init)
            {
				response = new PluginValue(texture_id);
                new std::thread(startCEF);
                init = true;
                result = 1;
            }
        }
		else if (name.compare("loadUrl") == 0) {
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

    void setTextureId(int textureId)
    {
		texture_id = textureId;
    }
}