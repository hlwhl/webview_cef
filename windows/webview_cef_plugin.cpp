#include "webview_cef_plugin.h"
#include "webview_cef_keyevent.h"
// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter_windows.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <thread>
#include <iostream>
#include <mutex>

namespace webview_cef {
	class WebviewTextureRenderer : public WebviewTexture{
	public:
		WebviewTextureRenderer(FlutterDesktopTextureRegistrarRef texture_registrar) {
			registrar_ = texture_registrar;
			texture = std::make_unique<flutter::TextureVariant>(
				flutter::PixelBufferTexture([this](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
					return this->CopyPixelBuffer(width, height);
				}));
			FlutterDesktopTextureInfo info = {};
			info.type = kFlutterDesktopPixelBufferTexture;
			info.pixel_buffer_config.user_data = std::get_if<flutter::PixelBufferTexture>(texture.get());
			info.pixel_buffer_config.callback = [](size_t width, size_t height, void* user_data) -> const FlutterDesktopPixelBuffer* {
				auto texture = static_cast<flutter::PixelBufferTexture*>(user_data);
				return texture->CopyPixelBuffer(width, height);
			};
			textureId = FlutterDesktopTextureRegistrarRegisterExternalTexture(registrar_, &info);
		}

		virtual ~WebviewTextureRenderer() {
			std::lock_guard<std::mutex> autolock(mutex_);
			if(registrar_){
				// FlutterDesktopTextureRegistrarUnregisterExternalTexture(registrar_, textureId, nullptr, nullptr);
			}
		}

		const FlutterDesktopPixelBuffer *CopyPixelBuffer(size_t width, size_t height) const{
			std::lock_guard<std::mutex> autolock(mutex_);
    		return pixel_buffer.get();
		}

		virtual void onFrame(const void* buffer, int width, int height) override{
			const std::lock_guard<std::mutex> autolock(mutex_);
			if (!pixel_buffer.get() || pixel_buffer.get()->width != width || pixel_buffer.get()->height != height) {
				if (!pixel_buffer.get()) {
					pixel_buffer = std::make_unique<FlutterDesktopPixelBuffer>();
					pixel_buffer->release_context = nullptr;
				}
				pixel_buffer->width = width;
				pixel_buffer->height = height;
				const auto size = width * height * 4;
				backing_pixel_buffer.reset(new uint8_t[size]);
				pixel_buffer->buffer = backing_pixel_buffer.get();
			}

			SwapBufferFromBgraToRgba((void*)pixel_buffer->buffer, buffer, width, height);
			if(registrar_){
				FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable(registrar_, textureId);
			}
		}

		FlutterDesktopTextureRegistrarRef registrar_;
		std::unique_ptr<flutter::TextureVariant> texture;
		mutable std::shared_ptr<FlutterDesktopPixelBuffer> pixel_buffer;
		std::unique_ptr<uint8_t> backing_pixel_buffer;
		mutable std::mutex mutex_;
	};

	static flutter::EncodableValue encode_wvalue_to_flvalue(WValue* args) {
		WValueType type = webview_value_get_type(args);
		switch(type){
			case Webview_Value_Type_Bool:
				return flutter::EncodableValue(webview_value_get_bool(args));
			case Webview_Value_Type_Int:
				return flutter::EncodableValue(webview_value_get_int(args));
			case Webview_Value_Type_Float:
				return flutter::EncodableValue(webview_value_get_float(args));
			case Webview_Value_Type_Double:
				return flutter::EncodableValue(webview_value_get_double(args));
			case Webview_Value_Type_String:
				return flutter::EncodableValue(webview_value_get_string(args));
			case Webview_Value_Type_Uint8_List:
				return flutter::EncodableValue(webview_value_get_uint8_list(args));
			case Webview_Value_Type_Int32_List:
				return flutter::EncodableValue(webview_value_get_int32_list(args));
			case Webview_Value_Type_Int64_List:
				return flutter::EncodableValue(webview_value_get_int64_list(args));
			case Webview_Value_Type_Float_List:
				return flutter::EncodableValue(webview_value_get_float_list(args));
			case Webview_Value_Type_Double_List:
				return flutter::EncodableValue(webview_value_get_double_list(args));
			case Webview_Value_Type_List:
			{
				flutter::EncodableList ret;
				size_t len = webview_value_get_len(args);
				for (size_t i = 0; i < len; i++) {
                	ret.push_back(encode_wvalue_to_flvalue(webview_value_get_list_value(args, i)));
				}
				return ret;
			}
			case Webview_Value_Type_Map:
			{
				flutter::EncodableMap ret;
				size_t len = webview_value_get_len(args);
				for (size_t i = 0; i < len; i++) {
					ret[encode_wvalue_to_flvalue(webview_value_get_key(args, i))] = encode_wvalue_to_flvalue(webview_value_get_value(args, i));
				}
				return ret;
			}
			default:
				return flutter::EncodableValue(nullptr);
		}
	}

	static WValue *encode_flvalue_to_wvalue(flutter::EncodableValue* args) {
		size_t index = args->index();
		if (index == 1) {
			return webview_value_new_bool(*std::get_if<bool>(args));
		}
		else if (index == 2 || index == 3) {
			return webview_value_new_int(*std::get_if<int32_t>(args));
		}
		else if (index == 4) {
			return webview_value_new_double(*std::get_if<double>(args));
		}
		else if (index == 5) {
			return webview_value_new_string((*std::get_if<std::string>(args)).c_str());
		}
		else if (index == 6) {
			auto list = *std::get_if<std::vector<uint8_t>>(args);
			return webview_value_new_uint8_list(list.data(), list.size());
		}
		else if (index == 7) {
			auto list = *std::get_if<std::vector<int32_t>>(args);
			return webview_value_new_int32_list(list.data(), list.size());
		}
		else if (index == 8) {
			auto list = *std::get_if<std::vector<int64_t>>(args);
			return webview_value_new_int64_list(list.data(), list.size());
		}
		else if (index == 9) {
			auto list = *std::get_if<std::vector<double>>(args);
			return webview_value_new_double_list(list.data(), list.size());
		}
		else if (index == 10) {
			WValue * ret = webview_value_new_list();
			flutter::EncodableList list = *std::get_if<flutter::EncodableList>(args);
			for (size_t i = 0; i < list.size(); i++) {
				WValue *value = encode_flvalue_to_wvalue(&list[i]);
				webview_value_append(ret, value);
				webview_value_unref(value);
			}
			return ret;
		}
		else if (index == 11) {
			WValue * ret = webview_value_new_map();
			flutter::EncodableMap map = *std::get_if<flutter::EncodableMap>(args);
			for (flutter::EncodableMap::iterator it = map.begin(); it != map.end(); it++)
			{
				WValue *key = encode_flvalue_to_wvalue(const_cast<flutter::EncodableValue *>(&it->first));
				WValue *value = encode_flvalue_to_wvalue(const_cast<flutter::EncodableValue*>(&it->second));
				webview_value_set(ret, key, value);
				webview_value_unref(key);
				webview_value_unref(value);
			}
			return ret;
		}
		else if (index == 12) {
			return nullptr;
		}
		else if (index == 13) {
			auto list = *std::get_if<std::vector<float>>(args);
			return webview_value_new_float_list(list.data(), list.size());
		}
		return nullptr;
	}

	std::unordered_map<HWND, std::shared_ptr<WebviewPlugin>> webviewPlugins;
	std::unordered_map<HWND, std::function<void(std::string method,flutter::EncodableValue * arguments)>> webviewChannels;

	void WebviewCefPlugin::RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {

		auto plugin = std::make_unique<WebviewCefPlugin>();
		plugin->m_textureRegistrar = FlutterDesktopRegistrarGetTextureRegistrar(registrar);
		flutter::PluginRegistrarWindows *window_registrar = flutter::PluginRegistrarManager::GetInstance()
																->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
		plugin->m_channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				window_registrar->messenger(), "webview_cef",
				&flutter::StandardMethodCodec::GetInstance());

		plugin->m_channel->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto &call, auto result)
			{
				plugin_pointer->HandleMethodCall(call, std::move(result));
			});

		plugin->m_hwnd = FlutterDesktopViewGetHWND(FlutterDesktopPluginRegistrarGetView(registrar));
		webviewPlugins.emplace(plugin->m_hwnd, plugin->m_plugin);
		webviewChannels.emplace(plugin->m_hwnd, [plugin_pointer = plugin.get()](std::string method, flutter::EncodableValue* arguments) {
			plugin_pointer->m_channel->InvokeMethod(method, std::make_unique<flutter::EncodableValue>(*arguments));
			});
		plugin->m_plugin->setInvokeMethodFunc([plugin_pointer = plugin.get()](std::string method, WValue* arguments) {
			flutter::EncodableValue* methodValue = new flutter::EncodableValue(method);
			flutter::EncodableValue* args = new flutter::EncodableValue(encode_wvalue_to_flvalue(arguments));
			PostMessage(plugin_pointer->m_hwnd, WM_USER + 1, WPARAM(methodValue), LPARAM(args));
			});

		plugin->m_plugin->setCreateTextureFunc([plugin_pointer = plugin.get()]() {
			std::shared_ptr<WebviewTextureRenderer> renderer = std::make_shared<WebviewTextureRenderer>(plugin_pointer->m_textureRegistrar);
			return std::dynamic_pointer_cast<WebviewTexture>(renderer);
		});

		window_registrar->AddPlugin(std::move(plugin));
	}
		
	WebviewCefPlugin::WebviewCefPlugin() {
		m_plugin = std::make_shared<WebviewPlugin>();
	}

	WebviewCefPlugin::~WebviewCefPlugin() {
        m_plugin = nullptr;
		webviewPlugins.erase(m_hwnd);
		webviewChannels.erase(m_hwnd);
        if(webviewPlugins.empty()){
			webview_cef::stopCEF();
		}
	}

	void WebviewCefPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
		WValue *encodeArgs = encode_flvalue_to_wvalue(const_cast<flutter::EncodableValue *>(method_call.arguments()));
		m_plugin->HandleMethodCall(method_call.method_name(), encodeArgs, [=](int ret, WValue* args){
			if (ret > 0){
				result->Success(encode_wvalue_to_flvalue(args));
			}
			else if (ret < 0){
				result->Error("error", "error", encode_wvalue_to_flvalue(args));
			}
			else{
				result->NotImplemented();
			}
		});
		webview_value_unref(encodeArgs);
	}

	void WebviewCefPlugin::handleMessageProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
		switch (message) {
		case WM_USER + 1:
		{
			if (webviewPlugins.find(hwnd) != webviewPlugins.end()) {
				flutter::EncodableValue *method = (flutter::EncodableValue *)wparam;
				flutter::EncodableValue *args = (flutter::EncodableValue *)lparam;
				webviewChannels[hwnd]((*std::get_if<std::string>(method)), args);
			}
			break;
		}
		case WM_SYSCHAR:
		case WM_SYSKEYDOWN:
		case WM_SYSKEYUP:
		case WM_KEYDOWN:
		case WM_KEYUP:
		case WM_CHAR:{
			if(webviewPlugins.find(hwnd)!=webviewPlugins.end()){
				CefKeyEvent keyEvent = getCefKeyEvent(message, wparam, lparam);
				webviewPlugins[hwnd]->sendKeyEvent(keyEvent);
			}
		}
		}
	}

}  // namespace webview_cef
