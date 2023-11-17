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

	std::unique_ptr<
		flutter::MethodChannel<flutter::EncodableValue>,
		std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
		channel = nullptr;

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
                	ret.push_back(encode_wvalue_to_flvalue(webview_value_get_value(args, i)));
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

		auto invoke = [=](std::string method, WValue* arguments) {
			flutter::EncodableValue args = encode_wvalue_to_flvalue(arguments);
			channel->InvokeMethod(method, std::make_unique<flutter::EncodableValue>(args));
  		};
  		webview_cef::setInvokeMethodFunc(invoke);

		registrar->AddPlugin(std::move(plugin));
	}

	WebviewCefPlugin::WebviewCefPlugin() {}

	WebviewCefPlugin::~WebviewCefPlugin() {}

	void WebviewCefPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
		if (method_call.method_name().compare("init") == 0) {
			texture_id = texture_registrar->RegisterTexture(m_texture.get());
			auto callback = [=](const void* buffer, int32_t width, int32_t height) {
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

				webview_cef::SwapBufferFromBgraToRgba((void*)pixel_buffer->buffer, buffer, width, height);
				texture_registrar->MarkTextureFrameAvailable(texture_id);
			};
			webview_cef::setPaintCallBack(callback);
			result->Success(flutter::EncodableValue(texture_id));
		}
		else{
			WValue *encodeArgs = encode_flvalue_to_wvalue(const_cast<flutter::EncodableValue *>(method_call.arguments()));
			WValue *responseArgs = nullptr;
			int ret = webview_cef::HandleMethodCall(method_call.method_name(), encodeArgs, responseArgs);
			if (ret > 0){
				result->Success(encode_wvalue_to_flvalue(responseArgs));
			}
			else if (ret < 0){
				result->Error("error", "error", encode_wvalue_to_flvalue(responseArgs));
			}
			else{
				result->NotImplemented();
			}
			webview_value_unref(encodeArgs);
			webview_value_unref(responseArgs);
		}
	}

}  // namespace webview_cef
