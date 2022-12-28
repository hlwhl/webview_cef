#include "webview_cef_plugin.h"

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <thread>
#include <mutex>

#include "webview_app.h"
#include "texture_handler.h"

namespace webview_cef {
	bool init = false;

	flutter::TextureRegistrar* texture_registrar;
	flutter::BinaryMessenger* messenger;

	CefRefPtr<WebviewApp> app;
	CefMainArgs mainArgs;

	void startCEF() {
		CefWindowInfo window_info;
		CefBrowserSettings settings;
		window_info.SetAsWindowless(nullptr);

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

	// static
	void WebviewCefPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		texture_registrar = registrar->texture_registrar();
		messenger = registrar->messenger();
		auto plugin_channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				messenger, "webview_cef", &flutter::StandardMethodCodec::GetInstance());

		auto plugin = std::make_unique<WebviewCefPlugin>();
		plugin_channel->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto& call, auto result) {
				plugin_pointer->HandleMethodCall(call, std::move(result));
			});
		app = new WebviewApp(std::move(plugin_channel));
		registrar->AddPlugin(std::move(plugin));
	}

	void WebviewCefPlugin::sendKeyEvent(CefKeyEvent ev)
	{
		// handler.get()->sendKeyEvent(ev);
	}

	WebviewCefPlugin::WebviewCefPlugin() {}

	WebviewCefPlugin::~WebviewCefPlugin() {}

	void WebviewCefPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
		if (method_call.method_name().compare("startCEF") == 0) {
			if (!init) {
				new std::thread(startCEF);
				init = true;
			}
			result->Success();
		} else if (method_call.method_name().compare("createBrowser") == 0) {
			auto const browser_id = *std::get_if<int>(method_call.arguments());
			auto handler = new WebviewHandler(messenger, browser_id);
			auto texture_handler = new TextureHandler(texture_registrar);
			handler->onPaintCallback = [texture_handler](const void* buffer, int32_t width, int32_t height) {
				texture_handler->onPaintCallback(buffer, width, height);
			};
			handler->onBrowserClose = [texture_handler] () mutable {
				delete texture_handler;
			};

			app->CreateBrowser(handler);
			result->Success(flutter::EncodableValue(texture_handler->texture_id()));
		}
		else {
			result->NotImplemented();
		}
	}

}  // namespace webview_cef
