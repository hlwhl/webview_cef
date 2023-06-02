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
#include <iostream>
#include <mutex>

namespace webview_cef {
	bool init = false;
	int64_t texture_id;

	flutter::TextureRegistrar* texture_registrar;
	std::shared_ptr<FlutterDesktopPixelBuffer> pixel_buffer;
	std::unique_ptr<uint8_t> backing_pixel_buffer;
	std::mutex buffer_mutex_;
	std::unique_ptr<flutter::TextureVariant> m_texture = std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture([](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
		buffer_mutex_.lock();
		auto buffer = pixel_buffer.get();
		// Only lock the mutex if the buffer is not null
		// (to ensure the release callback gets called)
		if (!buffer) {
			buffer_mutex_.unlock();
		}
		return buffer;
		}));
	CefRefPtr<WebviewHandler> handler(new WebviewHandler());
	CefRefPtr<WebviewApp> app(new WebviewApp(handler));
	CefMainArgs mainArgs;

	std::unique_ptr<
		flutter::MethodChannel<flutter::EncodableValue>,
		std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
		channel = nullptr;


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

		handler.get()->onUrlChangedCb = [](std::string url) {
			channel->InvokeMethod("urlChanged", std::make_unique<flutter::EncodableValue>(url));
		};

		handler.get()->onTitleChangedCb = [](std::string title) {
			channel->InvokeMethod("titleChanged", std::make_unique<flutter::EncodableValue>(title));
		};

		handler.get()->onAllCookieVisitedCb = [](std::map<std::string, std::map<std::string, std::string>> cookies) {
			flutter::EncodableMap retMap;
			for (auto& cookie : cookies)
			{
				flutter::EncodableMap tempMap;
				for (auto& c : cookie.second)
				{
					tempMap[flutter::EncodableValue(c.first)] = flutter::EncodableValue(c.second);
				}
				retMap[flutter::EncodableValue(cookie.first)] = flutter::EncodableValue(tempMap);
			}
			channel->InvokeMethod("allCookiesVisited", std::make_unique<flutter::EncodableValue>(retMap));
		};

		handler.get()->onUrlCookieVisitedCb = [](std::map<std::string, std::map<std::string, std::string>> cookies) {
			flutter::EncodableMap retMap;
			for (auto& cookie : cookies)
			{
				flutter::EncodableMap tempMap;
				for (auto& c : cookie.second)
				{
					tempMap[flutter::EncodableValue(c.first)] = flutter::EncodableValue(c.second);
				}
				retMap[flutter::EncodableValue(cookie.first)] = flutter::EncodableValue(tempMap);
			}
			channel->InvokeMethod("urlCookiesVisited", std::make_unique<flutter::EncodableValue>(retMap));
		};

		handler.get()->onJavaScriptChannelMessage = [](std::string channelName, std::string message, std::string callbackId, std::string frameId) {
			flutter::EncodableMap retMap;
			retMap[flutter::EncodableValue("channel")] = flutter::EncodableValue(channelName);
			retMap[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
			retMap[flutter::EncodableValue("callbackId")] = flutter::EncodableValue(callbackId);
			retMap[flutter::EncodableValue("frameId")] = flutter::EncodableValue(frameId);
			channel->InvokeMethod("javascriptChannelMessage", std::make_unique<flutter::EncodableValue>(retMap));
		};

		handler.get()->onFocusedNodeChangeMessage = [](bool editable) {
			channel->InvokeMethod("onFocusedNodeChangeMessage", std::make_unique<flutter::EncodableValue>(editable));
		};

		handler.get()->onImeCompositionRangeChangedMessage = [](int32_t x, int32_t y) {
			flutter::EncodableMap retMap;
			retMap[flutter::EncodableValue("x")] = flutter::EncodableValue(x);
			retMap[flutter::EncodableValue("y")] = flutter::EncodableValue(y);
			channel->InvokeMethod("onImeCompositionRangeChangedMessage", std::make_unique<flutter::EncodableValue>(retMap));
		};

		CefSettings cefs;
		cefs.windowless_rendering_enabled = true;
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
		channel =
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

	void WebviewCefPlugin::sendKeyEvent(CefKeyEvent ev)
	{
		handler.get()->sendKeyEvent(ev);
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
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto dpi = *std::get_if<double>(&(*list)[0]);
			const auto width = *std::get_if<double>(&(*list)[1]);
			const auto height = *std::get_if<double>(&(*list)[2]);
			handler.get()->changeSize((float)dpi, (int)std::round(width), (int)std::round(height));
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
		else if (method_call.method_name().compare("cursorMove") == 0) {
			const auto point = GetPointFromArgs(method_call.arguments());
			handler.get()->cursorMove(point->first, point->second, false);
			result->Success();
		}
		else if (method_call.method_name().compare("cursorDragging") == 0) {
			const auto point = GetPointFromArgs(method_call.arguments());
			handler.get()->cursorMove(point->first, point->second, true);
			result->Success();
		}
		else if (method_call.method_name().compare("setScrollDelta") == 0) {
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto x = *std::get_if<int>(&(*list)[0]);
			const auto y = *std::get_if<int>(&(*list)[1]);
			const auto deltaX = *std::get_if<int>(&(*list)[2]);
			const auto deltaY = *std::get_if<int>(&(*list)[3]);
			handler.get()->sendScrollEvent(x, y, deltaX, deltaY);
			result->Success();
		}
		else if (method_call.method_name().compare("goForward") == 0) {
			handler.get()->goForward();
			result->Success();
		}
		else if (method_call.method_name().compare("goBack") == 0) {
			handler.get()->goBack();
			result->Success();
		}
		else if (method_call.method_name().compare("reload") == 0) {
			handler.get()->reload();
			result->Success();
		}
		else if (method_call.method_name().compare("openDevTools") == 0) {
			handler.get()->openDevTools();
			result->Success();
		}
		else if (method_call.method_name().compare("imeSetComposition") == 0) {
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto text = *std::get_if<std::string>(&(*list)[0]);
			handler.get()->imeSetComposition(text);
			result->Success();
		} 
		else if (method_call.method_name().compare("imeCommitText") == 0) {
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto text = *std::get_if<std::string>(&(*list)[0]);
			handler.get()->imeCommitText(text);
			result->Success();
		} 
		else if (method_call.method_name().compare("setClientFocus") == 0) {
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto focus = *std::get_if<bool>(&(*list)[0]);
			handler.get()->setClientFocus(focus);
			result->Success();
		}
		else if(method_call.method_name().compare("setCookie") == 0){
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto domain = *std::get_if<std::string>(&(*list)[0]);
			const auto key = *std::get_if<std::string>(&(*list)[1]);
			const auto value = *std::get_if<std::string>(&(*list)[2]);
			handler.get()->setCookie(domain, key, value);
			result->Success();
		}
		else if (method_call.method_name().compare("deleteCookie") == 0) {
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto domain = *std::get_if<std::string>(&(*list)[0]);
			const auto key = *std::get_if<std::string>(&(*list)[1]);
			handler.get()->deleteCookie(domain, key);
			result->Success();
		}
		else if (method_call.method_name().compare("visitAllCookies") == 0) {
			handler.get()->visitAllCookies();
			result->Success();
		}
		else if (method_call.method_name().compare("visitUrlCookies") == 0) {
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto domain = *std::get_if<std::string>(&(*list)[0]);
			const auto isHttpOnly = *std::get_if<bool>(&(*list)[1]);
			handler.get()->visitUrlCookies(domain, isHttpOnly);
			result->Success();
		}
		else if(method_call.method_name().compare("setJavaScriptChannels") == 0){
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto jsChannels = *std::get_if<std::vector<flutter::EncodableValue>>(&(*list)[0]);
			std::vector<std::string> channels;
			for (auto& jsChannel : jsChannels) {
				channels.push_back(*std::get_if<std::string>(&(jsChannel)));
			}
			handler.get()->setJavaScriptChannels(channels);
			result->Success();
		}
		else if (method_call.method_name().compare("sendJavaScriptChannelCallBack") == 0) {
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto error = *std::get_if<bool>(&(*list)[0]);
			const auto ret = *std::get_if<std::string>(&(*list)[1]);
			const auto callbackId = *std::get_if<std::string>(&(*list)[2]);
			const auto frameId = *std::get_if<std::string>(&(*list)[3]);
			handler.get()->sendJavaScriptChannelCallBack(error, ret,callbackId,frameId);
			result->Success();
		}
		else if(method_call.method_name().compare("executeJavaScript") == 0){
			const flutter::EncodableList* list =
				std::get_if<flutter::EncodableList>(method_call.arguments());
			const auto code = *std::get_if<std::string>(&(*list)[0]);
			handler.get()->executeJavaScript(code);
			result->Success();	
		}
		else {
			result->NotImplemented();
		}
	}

}  // namespace webview_cef
