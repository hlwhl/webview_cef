#include "webview_cef_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <thread>
#include<iostream>
#include <mutex>

#include "include/cef_app.h"
#include "simple_app.h"

namespace webview_cef {
	bool init = false;
	int64_t texture_id;
	
	flutter::TextureRegistrar* texture_registrar;
	std::shared_ptr<FlutterDesktopPixelBuffer> pixel_buffer;
	std::unique_ptr<uint8_t> backing_pixel_buffer;
	std::mutex buffer_mutex_;
	std::unique_ptr<flutter::TextureVariant> m_texture = std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture([](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
		auto buffer = pixel_buffer.get();
		// Only lock the mutex if the buffer is not null
		// (to ensure the release callback gets called)
		if (buffer) {
			// Gets unlocked in the FlutterDesktopPixelBuffer's release callback.
			buffer_mutex_.lock();
		}
		return buffer;
		}));
	CefRefPtr<SimpleHandler> handler(new SimpleHandler(false));
	CefRefPtr<SimpleApp> app(new SimpleApp(handler));
	CefMainArgs mainArgs;


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

	void startCEF() {
		CefWindowInfo window_info;
		CefBrowserSettings settings;
		window_info.SetAsWindowless(nullptr);

		handler.get()->onPaintCallback = [](const void* buffer, int32_t width, int32_t height) {
			const std::lock_guard<std::mutex> lock(buffer_mutex_);
			if (!pixel_buffer.get() || pixel_buffer.get()->width != width || pixel_buffer.get()->height != height) {
				if (!pixel_buffer.get()) {
					pixel_buffer = std::make_unique<FlutterDesktopPixelBuffer>();
					pixel_buffer->release_context = &buffer_mutex_;
					// Gets invoked after the FlutterDesktopPixelBuffer's
					// backing buffer has been uploaded.
					pixel_buffer->release_callback = [](void* opaque) {
						auto mutex = reinterpret_cast<std::mutex*>(opaque);
						// Gets locked just before |CopyPixelBuffer| returns.
						mutex->unlock();
					};
				}
				pixel_buffer->width = width;
				pixel_buffer->height = height;
				const auto size = width * height * 4;
				backing_pixel_buffer.reset(new uint8_t[size]);
				pixel_buffer->buffer = backing_pixel_buffer.get();
			}

			SwapBufferFromBgraToRgba((void*)pixel_buffer->buffer, buffer, width, height);
			texture_registrar->MarkTextureFrameAvailable(texture_id);
		};

		CefSettings cefs;
		cefs.windowless_rendering_enabled = true;
		/*app.get()->handler->onPaintCallback = [tid](const void* buffer, int width, int height) {
			if (!pixel_buffer.get()) {
				pixel_buffer.reset(new FlutterDesktopPixelBuffer());
				pixel_buffer->buffer = (uint8_t*)malloc(width * height * 4);
				pixel_buffer->width = width;
				pixel_buffer->height = height;
			}
			SwapBufferFromBgraToRgba((void*)pixel_buffer->buffer, buffer, width, height);
			texture_registrar->MarkTextureFrameAvailable(tid);
		};*/
		CefInitialize(mainArgs, cefs, app.get(), nullptr);
		CefRunMessageLoop();
		CefShutdown();
	}

	template <typename T>
	std::optional<T> GetOptionalValue(const flutter::EncodableMap& map,
		const std::string& key) {
		const auto it = map.find(flutter::EncodableValue(key));
		if (it != map.end()) {
			const auto val = std::get_if<T>(&it->second);
			if (val) {
				return *val;
			}
		}
		return std::nullopt;
	}

	static const std::optional<std::pair<int, int>> GetPointFromArgs(
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

	// static
	void WebviewCefPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		texture_registrar = registrar->texture_registrar();
		auto channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				registrar->messenger(), "webview_cef",
				&flutter::StandardMethodCodec::GetInstance());

		auto plugin = std::make_unique<WebviewCefPlugin>();

		channel->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto& call, auto result) {
			plugin_pointer->HandleMethodCall(call, std::move(result));
		});

		registrar->AddPlugin(std::move(plugin));
	}

	WebviewCefPlugin::WebviewCefPlugin() {}

	WebviewCefPlugin::~WebviewCefPlugin() {}

	void WebviewCefPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
		if (method_call.method_name().compare("init") == 0) {
			if (!init) {
				texture_id = texture_registrar->RegisterTexture(m_texture.get());
				new std::thread(startCEF);
				init = true;
			}
			result->Success(flutter::EncodableValue(texture_id));
		}
		else if (method_call.method_name().compare("loadUrl") == 0) {
			if (const auto url = std::get_if<std::string>(method_call.arguments())) {
				handler.get()->loadUrl(*url);
				return result->Success();
			}
		}
		else if (method_call.method_name().compare("setSize") == 0) {
			const auto point = GetPointFromArgs(method_call.arguments());
			handler.get()->changeSize(point->first, point->second);
			result->Success();
		}
		else if (method_call.method_name().compare("cursorClickDown") == 0) {
			const auto point = GetPointFromArgs(method_call.arguments());
			handler.get()->cursorClick(point->first, point->second, false);
			result->Success();
		}
		else if (method_call.method_name().compare("cursorClickUp") == 0) {
			const auto point = GetPointFromArgs(method_call.arguments());
			handler.get()->cursorClick(point->first, point->second, true);
			result->Success();
		}
		else if (method_call.method_name().compare("setScrollDelta") == 0) {
			const auto point = GetPointFromArgs(method_call.arguments());
			if (point->second > 0) {
				handler.get()->scrollDown();
			}
			else if (point->second < 0) {
				handler.get()->scrollUp();
			}
			result->Success();
		}
		else {
			result->NotImplemented();
		}
	}

}  // namespace webview_cef
