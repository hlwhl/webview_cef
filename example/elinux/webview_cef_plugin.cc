#include "include/webview_cef/webview_cef_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

#include "webview_cef_texture.h"
#include <webview_plugin.h>

namespace webview_cef {

class WebviewCefPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrar* registrar);

  WebviewCefPlugin(flutter::PluginRegistrar* registrar);

  virtual ~WebviewCefPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableValue EncodeWValue(WValue* value);
  WValue* DecodeEncodableValue(const flutter::EncodableValue& value);

  flutter::PluginRegistrar* registrar_;
  std::shared_ptr<WebviewPlugin> plugin_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

// static
void WebviewCefPlugin::RegisterWithRegistrar(flutter::PluginRegistrar* registrar) {
  auto plugin = std::make_unique<WebviewCefPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

WebviewCefPlugin::WebviewCefPlugin(flutter::PluginRegistrar* registrar)
    : registrar_(registrar) {
  plugin_ = std::make_shared<WebviewPlugin>();
  
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "webview_cef",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });

  plugin_->setInvokeMethodFunc([this](std::string method, WValue* arguments) {
    channel_->InvokeMethod(method, std::make_unique<flutter::EncodableValue>(EncodeWValue(arguments)));
  });

  plugin_->setCreateTextureFunc([this]() {
    auto renderer = std::make_shared<WebviewTextureRenderer>(registrar_->texture_registrar());
    return std::dynamic_pointer_cast<WebviewTexture>(renderer);
  });
}

WebviewCefPlugin::~WebviewCefPlugin() {
    // stopCEF() should be called when last plugin is destroyed if needed, 
    // but usually it's handled at app exit.
}

void WebviewCefPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const std::string& method = method_call.method_name();
  WValue* args = DecodeEncodableValue(*method_call.arguments());

   fprintf(stderr, "ELINUX (example): Received method call: %s\n", method.c_str());
  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared_result = std::move(result);

  plugin_->HandleMethodCall(method, args, [this, shared_result, method, args](int ret, WValue* responseArgs) {
    if (ret > 0) {
      shared_result->Success(EncodeWValue(responseArgs));
    } else if (ret < 0) {
      shared_result->Error("error", "error", EncodeWValue(responseArgs));
    } else if (method == "sendKeyEvent") {
        // Handle sendKeyEvent separately if needed, but it seems common code might handle it if ret == 0?
        // Actually the GTK implementation had special handling for sendKeyEvent when ret == 0.
        // Let's check if we can replicate it.
        if (webview_value_get_type(args) == Webview_Value_Type_Map) {
            CefKeyEvent key_event;
            WValue* browser_id_val = webview_value_get_by_string(args, "browserId");
            WValue* type_val = webview_value_get_by_string(args, "type");
            WValue* modifiers_val = webview_value_get_by_string(args, "modifiers");
            WValue* windows_key_code_val = webview_value_get_by_string(args, "windows_key_code");
            WValue* native_key_code_val = webview_value_get_by_string(args, "native_key_code");
            WValue* is_system_key_val = webview_value_get_by_string(args, "is_system_key");
            WValue* character_val = webview_value_get_by_string(args, "character");
            WValue* unmodified_character_val = webview_value_get_by_string(args, "unmodified_character");

            if (type_val) key_event.type = (cef_key_event_type_t)webview_value_get_int(type_val);
            if (modifiers_val) key_event.modifiers = webview_value_get_int(modifiers_val);
            if (windows_key_code_val) key_event.windows_key_code = webview_value_get_int(windows_key_code_val);
            if (native_key_code_val) key_event.native_key_code = webview_value_get_int(native_key_code_val);
            if (is_system_key_val) key_event.is_system_key = webview_value_get_bool(is_system_key_val);
            if (character_val) key_event.character = webview_value_get_int(character_val);
            if (unmodified_character_val) key_event.unmodified_character = webview_value_get_int(unmodified_character_val);

            if (browser_id_val) {
                int browser_id = webview_value_get_int(browser_id_val);
                plugin_->sendKeyEvent(browser_id, key_event);
            } else {
                plugin_->sendKeyEvent(key_event);
            }
            shared_result->Success();
        } else {
            shared_result->Error("error", "Invalid arguments for sendKeyEvent");
        }
    } else {
      shared_result->NotImplemented();
    }
  });
  
  webview_value_unref(args);
}

flutter::EncodableValue WebviewCefPlugin::EncodeWValue(WValue* value) {
  WValueType type = webview_value_get_type(value);
  switch (type) {
    case Webview_Value_Type_Bool:
      return flutter::EncodableValue(webview_value_get_bool(value));
    case Webview_Value_Type_Int:
      return flutter::EncodableValue(webview_value_get_int(value));
    case Webview_Value_Type_Float:
    case Webview_Value_Type_Double:
      return flutter::EncodableValue(webview_value_get_double(value));
    case Webview_Value_Type_String:
      return flutter::EncodableValue(webview_value_get_string(value));
    case Webview_Value_Type_Uint8_List: {
      const uint8_t* val = webview_value_get_uint8_list(value);
      size_t len = webview_value_get_len(value);
      return flutter::EncodableValue(std::vector<uint8_t>(val, val + len));
    }
    case Webview_Value_Type_List: {
      flutter::EncodableList list;
      size_t len = webview_value_get_len(value);
      for (size_t i = 0; i < len; i++) {
        list.push_back(EncodeWValue(webview_value_get_list_value(value, i)));
      }
      return flutter::EncodableValue(list);
    }
    case Webview_Value_Type_Map: {
      flutter::EncodableMap map;
      size_t len = webview_value_get_len(value);
      for (size_t i = 0; i < len; i++) {
        map[EncodeWValue(webview_value_get_key(value, i))] =
            EncodeWValue(webview_value_get_value(value, i));
      }
      return flutter::EncodableValue(map);
    }
    default:
      return flutter::EncodableValue();
  }
}

WValue* WebviewCefPlugin::DecodeEncodableValue(const flutter::EncodableValue& value) {
  if (std::holds_alternative<bool>(value)) {
    return webview_value_new_bool(std::get<bool>(value));
  } else if (std::holds_alternative<int32_t>(value)) {
    return webview_value_new_int(std::get<int32_t>(value));
  } else if (std::holds_alternative<int64_t>(value)) {
    return webview_value_new_int(std::get<int64_t>(value));
  } else if (std::holds_alternative<double>(value)) {
    return webview_value_new_double(std::get<double>(value));
  } else if (std::holds_alternative<std::string>(value)) {
    return webview_value_new_string(std::get<std::string>(value).c_str());
  } else if (std::holds_alternative<std::vector<uint8_t>>(value)) {
    const auto& vec = std::get<std::vector<uint8_t>>(value);
    return webview_value_new_uint8_list(vec.data(), vec.size());
  } else if (std::holds_alternative<flutter::EncodableList>(value)) {
    WValue* list = webview_value_new_list();
    for (const auto& item : std::get<flutter::EncodableList>(value)) {
      WValue* witem = DecodeEncodableValue(item);
      webview_value_append(list, witem);
      webview_value_unref(witem);
    }
    return list;
  } else if (std::holds_alternative<flutter::EncodableMap>(value)) {
    WValue* map = webview_value_new_map();
    for (const auto& [key, val] : std::get<flutter::EncodableMap>(value)) {
      WValue* wkey = DecodeEncodableValue(key);
      WValue* wval = DecodeEncodableValue(val);
      webview_value_set(map, wkey, wval);
      webview_value_unref(wkey);
      webview_value_unref(wval);
    }
    return map;
  }
  return webview_value_new_null();
}

void RegisterWithRegistrar(flutter::PluginRegistrar* registrar) {
  WebviewCefPlugin::RegisterWithRegistrar(registrar);
}

}  // namespace webview_cef

int initCEFProcesses(int argc, char** argv) {
  CefMainArgs main_args(argc, argv);
  return webview_cef::initCEFProcesses(main_args);
}
