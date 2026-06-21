#include "webview_cef_plugin.h"
#include "webview_cef_keyevent.h"
#ifdef WEBVIEW_CEF_GPU_TEXTURE
#include "webview_cef_gpu_texture.h"
#endif
// This must be included before many other Windows headers.
#include <windows.h>
#include <imm.h>
#include <commctrl.h>

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
		// A null value (or a Null-typed WValue) maps to a null EncodableValue.
		// Note: EncodableValue(nullptr) must NOT be used — under C++20 it resolves
		// to std::string(const char*=nullptr) and crashes in strlen.
		if (args == nullptr) {
			return flutter::EncodableValue();
		}
		WValueType type = webview_value_get_type(args);
		switch(type){
			case Webview_Value_Type_Bool:
				return flutter::EncodableValue(webview_value_get_bool(args));
			case Webview_Value_Type_Int:
				return flutter::EncodableValue(webview_value_get_int(args));
			case Webview_Value_Type_Float:
				// flutter::EncodableValue has no scalar float alternative; C++20's
				// stricter std::variant rules no longer auto-promote float to double.
				return flutter::EncodableValue(static_cast<double>(webview_value_get_float(args)));
			case Webview_Value_Type_Double:
				return flutter::EncodableValue(webview_value_get_double(args));
			case Webview_Value_Type_String:
				return flutter::EncodableValue(webview_value_get_string(args));
			case Webview_Value_Type_Uint8_List: {
				const uint8_t* data = webview_value_get_uint8_list(args);
				return flutter::EncodableValue(std::vector<uint8_t>(data, data + webview_value_get_len(args)));
			}
			case Webview_Value_Type_Int32_List: {
				const int32_t* data = webview_value_get_int32_list(args);
				return flutter::EncodableValue(std::vector<int32_t>(data, data + webview_value_get_len(args)));
			}
			case Webview_Value_Type_Int64_List: {
				const int64_t* data = webview_value_get_int64_list(args);
				return flutter::EncodableValue(std::vector<int64_t>(data, data + webview_value_get_len(args)));
			}
			case Webview_Value_Type_Float_List: {
				const float* data = webview_value_get_float_list(args);
				return flutter::EncodableValue(std::vector<float>(data, data + webview_value_get_len(args)));
			}
			case Webview_Value_Type_Double_List: {
				const double* data = webview_value_get_double_list(args);
				return flutter::EncodableValue(std::vector<double>(data, data + webview_value_get_len(args)));
			}
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
				return flutter::EncodableValue();
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

	static constexpr UINT_PTR kImeSubclassId = 1;

	// The OS IME must be intercepted in the window procedure BEFORE DefWindowProc
	// runs, otherwise the default handling consumes/converts the result string and
	// shows its own composition window. We can't do that from the runner's
	// post-DispatchMessage hook, so the Flutter view HWND is subclassed here.
	static LRESULT CALLBACK ImeSubclassProc(HWND hwnd, UINT message, WPARAM wparam,
		LPARAM lparam, UINT_PTR, DWORD_PTR) {
		switch (message) {
		case WM_IME_SETCONTEXT:
			// Don't let the OS draw its own composition window; the preedit is
			// rendered inside the web page via ImeSetComposition.
			lparam &= ~ISC_SHOWUICOMPOSITIONWINDOW;
			return DefSubclassProc(hwnd, message, wparam, lparam);
		case WM_IME_STARTCOMPOSITION:
			// Suppress default composition UI; we drive composition ourselves.
			return 0;
		case WM_IME_COMPOSITION: {
			auto pit = webviewPlugins.find(hwnd);
			if (pit == webviewPlugins.end() || !pit->second->isEditableFocused()) {
				return DefSubclassProc(hwnd, message, wparam, lparam);
			}
			HIMC imc = ImmGetContext(hwnd);
			if (imc) {
				// Committed result -> commit it to the focused browser.
				if (lparam & GCS_RESULTSTR) {
					LONG bytes = ImmGetCompositionStringW(imc, GCS_RESULTSTR, nullptr, 0);
					if (bytes > 0) {
						std::wstring ws(bytes / sizeof(wchar_t), L'\0');
						ImmGetCompositionStringW(imc, GCS_RESULTSTR, &ws[0], bytes);
						pit->second->imeCommitTextNative(ws);
					}
				}
				// Ongoing preedit -> set composition (real-time on-screen text).
				if (lparam & GCS_COMPSTR) {
					LONG bytes = ImmGetCompositionStringW(imc, GCS_COMPSTR, nullptr, 0);
					if (bytes > 0) {
						std::wstring ws(bytes / sizeof(wchar_t), L'\0');
						ImmGetCompositionStringW(imc, GCS_COMPSTR, &ws[0], bytes);
						int cursor = static_cast<int>(
							ImmGetCompositionStringW(imc, GCS_CURSORPOS, nullptr, 0));
						pit->second->imeSetCompositionNative(ws, cursor);
					}
				}
				ImmReleaseContext(hwnd, imc);
			}
			// Consume: prevent DefWindowProc from showing the default IME window or
			// generating duplicate WM_IME_CHAR/WM_CHAR for the committed text.
			return 0;
		}
		case WM_IME_ENDCOMPOSITION: {
			auto pit = webviewPlugins.find(hwnd);
			if (pit != webviewPlugins.end()) {
				pit->second->imeFinishCompositionNative();
			}
			return DefSubclassProc(hwnd, message, wparam, lparam);
		}
		}
		return DefSubclassProc(hwnd, message, wparam, lparam);
	}

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
		// Subclass the Flutter view window to intercept WM_IME_* before the engine
		// and DefWindowProc handle them (required for correct CJK composition/commit).
		SetWindowSubclass(plugin->m_hwnd, ImeSubclassProc, kImeSubclassId, 0);
		webviewChannels.emplace(plugin->m_hwnd, [plugin_pointer = plugin.get()](std::string method, flutter::EncodableValue* arguments) {
			plugin_pointer->m_channel->InvokeMethod(method, std::make_unique<flutter::EncodableValue>(*arguments));
			});
		plugin->m_plugin->setInvokeMethodFunc([plugin_pointer = plugin.get()](std::string method, WValue* arguments) {
			flutter::EncodableValue* methodValue = new flutter::EncodableValue(method);
			flutter::EncodableValue* args = new flutter::EncodableValue(encode_wvalue_to_flvalue(arguments));
			PostMessage(plugin_pointer->m_hwnd, WM_USER + 1, WPARAM(methodValue), LPARAM(args));
			});

		plugin->m_plugin->setCreateTextureFunc([plugin_pointer = plugin.get()]() {
#ifdef WEBVIEW_CEF_GPU_TEXTURE
			// Zero-copy GPU path: CEF OnAcceleratedPaint shared texture -> Flutter
			// D3D11 surface texture. Falls back to the software pixel-buffer path
			// only if the D3D11 device could not be created.
			auto gpu = std::make_shared<WebviewGpuTextureRenderer>(plugin_pointer->m_textureRegistrar);
			if (gpu->isValid()) {
				return std::dynamic_pointer_cast<WebviewTexture>(gpu);
			}
#endif
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
		RemoveWindowSubclass(m_hwnd, ImeSubclassProc, kImeSubclassId);
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
			// These were heap-allocated in setInvokeMethodFunc; take ownership and
			// free them after dispatch (InvokeMethod copies the arguments).
			flutter::EncodableValue *method = (flutter::EncodableValue *)wparam;
			flutter::EncodableValue *args = (flutter::EncodableValue *)lparam;
			if (webviewPlugins.find(hwnd) != webviewPlugins.end()) {
				webviewChannels[hwnd]((*std::get_if<std::string>(method)), args);
			}
			delete method;
			delete args;
			break;
		}
		// WM_IME_* are handled in ImeSubclassProc (before DefWindowProc), not here.
		case WM_SYSCHAR:
		case WM_SYSKEYDOWN:
		case WM_SYSKEYUP:
		case WM_KEYDOWN:
		case WM_KEYUP:
		case WM_CHAR: {
			if (webviewPlugins.find(hwnd) != webviewPlugins.end()) {
				CefKeyEvent keyEvent = getCefKeyEvent(message, wparam, lparam);
				webviewPlugins[hwnd]->sendKeyEvent(keyEvent);
			}
			break;
		}
		}
	}

}  // namespace webview_cef
