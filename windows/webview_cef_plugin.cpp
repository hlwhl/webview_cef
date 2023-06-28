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

	WebviewCefPlugin::WebviewCefPlugin() {}

	WebviewCefPlugin::~WebviewCefPlugin() {}

	static flutter::EncodableValue encode_pluginvalue_to_flvalue(webview_cef::PluginValue *args){
		size_t index = args->index();
		if(index == 1){
			return flutter::EncodableValue(std::get_if<bool>(args));
		}else if(index == 2 || index == 3){
			return flutter::EncodableValue((int64_t)std::get_if<int>(args));
		}else if(index == 4){
			return flutter::EncodableValue(*std::get_if<double>(args));
		}else if(index == 5){
			std::string str = *std::get_if<std::string>(args);
			return flutter::EncodableValue(str.c_str());
		}else if(index == 6){
			std::vector<uint8_t> vec = *std::get_if<std::vector<uint8_t>>(args);
			return flutter::EncodableValue(vec);
		}else if(index == 7){
			std::vector<int32_t> vec = *std::get_if<std::vector<int32_t>>(args);
			return flutter::EncodableValue(vec);
		}else if(index == 8){
			std::vector<int64_t> vec = *std::get_if<std::vector<int64_t>>(args);
			return flutter::EncodableValue(vec);
		}else if(index == 9){
			std::vector<float> vec = *std::get_if<std::vector<float>>(args);
			return flutter::EncodableValue(vec);
		}else if(index == 10){
			std::vector<double> vec = *std::get_if<std::vector<double>>(args);
			return flutter::EncodableValue(vec);
		}else if(index == 11){
			flutter::EncodableList ret;
			webview_cef::PluginValueList vec = *std::get_if<webview_cef::PluginValueList>(args);
			for(size_t i=0;i<vec.size();i++){
				ret.push_back(encode_pluginvalue_to_flvalue(&vec[i]));
			}
			return ret;
		}else if(index == 12){
			flutter::EncodableMap ret;
			webview_cef::PluginValueMap maps = *std::get_if<webview_cef::PluginValueMap>(args);
			for(webview_cef::PluginValueMap::iterator it = maps.begin(); it != maps.end(); it++ )
			{
				webview_cef::PluginValue key = it->first;
				webview_cef::PluginValue val = it->second;
				ret[encode_pluginvalue_to_flvalue(&key)] = encode_pluginvalue_to_flvalue(&val);
			}
			return ret;
		}
		return flutter::EncodableValue(nullptr);
	}

	static webview_cef::PluginValue encode_flvalue_to_pluginvalue(flutter::EncodableValue *args){
		webview_cef::PluginValue ret;
		size_t index = args->index();
		if(index == 1){
			ret = webview_cef::PluginValue(std::get_if<bool>(args));
		}else if(index == 2){
			ret = webview_cef::PluginValue((int)*std::get_if<int32_t>(args));
		}else if(index == 3){
			ret = webview_cef::PluginValue((int)*std::get_if<int64_t>(args));
		}else if(index == 4){
			ret = webview_cef::PluginValue(*std::get_if<double>(args));
		}else if(index == 5){
			ret =  webview_cef::PluginValue(*std::get_if<std::string>(args));
		}else if(index == 6){
			std::vector<uint8_t> vec = *std::get_if<std::vector<uint8_t>>(args);
			ret = webview_cef::PluginValue(vec);
		}else if(index == 7){
			std::vector<int32_t> vec = *std::get_if<std::vector<int32_t>>(args);
			ret = webview_cef::PluginValue(vec);
		}else if(index == 8){
			std::vector<int64_t> vec = *std::get_if<std::vector<int64_t>>(args);
			ret = webview_cef::PluginValue(vec);
		}else if(index == 9){
			std::vector<double> vec = *std::get_if<std::vector<double>>(args);
			ret = webview_cef::PluginValue(vec);
		}else if(index == 10){
			webview_cef::PluginValueList vec;
			flutter::EncodableList list = *std::get_if<flutter::EncodableList>(args);
			for(size_t i=0;i<list.size();i++){
				vec.push_back(encode_flvalue_to_pluginvalue(&list[i]));
			}
			ret = webview_cef::PluginValue(vec);
		}else if(index == 11){
			webview_cef::PluginValueMap maps;
			flutter::EncodableMap map = *std::get_if<flutter::EncodableMap>(args);
			for(flutter::EncodableMap::iterator it = map.begin(); it != map.end(); it++ )
			{
				flutter::EncodableValue key = it->first;
				flutter::EncodableValue val = it->second;
				maps[encode_flvalue_to_pluginvalue(&key)] = encode_flvalue_to_pluginvalue(&val);
			}
			ret = webview_cef::PluginValue(maps);
		}else if(index == 12){

		}else if(index == 13){
			std::vector<float> vec = *std::get_if<std::vector<float>>(args);
			ret = webview_cef::PluginValue(vec);
		}
		return ret;
	}


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
			webview_cef::PluginValue encodeArgs = encode_flvalue_to_pluginvalue(const_cast<flutter::EncodableValue *>(method_call.arguments()));
			webview_cef::PluginValue responseArgs;
			int ret = webview_cef::HandleMethodCall(method_call.method_name(), &encodeArgs, &responseArgs);
			if (ret > 0){
				result->Success(encode_pluginvalue_to_flvalue(&responseArgs));
			}
			else if (ret < 0){
				result->Error("error", "error", encode_pluginvalue_to_flvalue(&responseArgs));
			}
			else{
				result->NotImplemented();
			}
		}
	}

}  // namespace webview_cef
