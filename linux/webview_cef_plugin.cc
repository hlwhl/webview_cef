#include "include/webview_cef/webview_cef_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include "../../common/webview_plugin.h"
#include "webview_cef_texture.h"

#define WEBVIEW_CEF_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), webview_cef_plugin_get_type(), \
                              WebviewCefPlugin))

struct _WebviewCefPlugin
{
  GObject parent_instance;
};

G_DEFINE_TYPE(WebviewCefPlugin, webview_cef_plugin, g_object_get_type())

static FlTextureRegistrar* texture_register;
auto m_texture = webview_cef_texture_new();

static FlValue* encode_pluginvalue_to_flvalue(webview_cef::PluginValue *args){
  int index = args->index();
  if(index == 1){
    return fl_value_new_bool(std::get_if<bool>(args));
  }else if(index == 2 || index == 3){
    return fl_value_new_int((int64_t)std::get_if<int>(args));
  }else if(index == 4){
    return fl_value_new_float(*std::get_if<double>(args));
  }else if(index == 5){
    std::string str = *std::get_if<std::string>(args);
    return fl_value_new_string(str.c_str());
  }else if(index == 6){
    std::vector<uint8_t> vec = *std::get_if<std::vector<uint8_t>>(args);
    return fl_value_new_uint8_list(&vec[0], vec.size());
  }else if(index == 7){
    std::vector<int32_t> vec = *std::get_if<std::vector<int32_t>>(args);
    return fl_value_new_int32_list(&vec[0], vec.size());
  }else if(index == 8){
    std::vector<int64_t> vec = *std::get_if<std::vector<int64_t>>(args);
    return fl_value_new_int64_list(&vec[0], vec.size());
  }else if(index == 9){
    std::vector<float> vec = *std::get_if<std::vector<float>>(args);
    return fl_value_new_float32_list(&vec[0], vec.size());
  }else if(index == 10){
    std::vector<double> vec = *std::get_if<std::vector<double>>(args);
    return fl_value_new_float_list(&vec[0], vec.size());
  }else if(index == 11){
    FlValue * ret = fl_value_new_list();
    webview_cef::PluginValueList vec = *std::get_if<webview_cef::PluginValueList>(args);
    for(size_t i=0;i<vec.size();i++){
      fl_value_append(ret, encode_pluginvalue_to_flvalue(&vec[i]));
    }
    return ret;
  }else if(index == 12){
    FlValue* ret = fl_value_new_map();
    webview_cef::PluginValueMap maps = *std::get_if<webview_cef::PluginValueMap>(args);
    for(webview_cef::PluginValueMap::iterator it = maps.begin(); it != maps.end(); it++ )
    {
      webview_cef::PluginValue key = it->first;
      webview_cef::PluginValue val = it->second;
      fl_value_set(ret, encode_pluginvalue_to_flvalue(&key), encode_pluginvalue_to_flvalue(&val));
    }
    return ret;
  }
  return fl_value_new_null();
}

static webview_cef::PluginValue encode_flvalue_to_pluginvalue(FlValue* args){
  webview_cef::PluginValue ret;
  FlValueType argsType = fl_value_get_type(args);
  switch (argsType)
  {
  case FlValueType::FL_VALUE_TYPE_NULL:
    ret = webview_cef::PluginValue(NULL);
    break;
  case FlValueType::FL_VALUE_TYPE_BOOL:{
    bool val = fl_value_get_bool(args);
    ret = webview_cef::PluginValue(val);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_INT:{
    int64_t val = fl_value_get_int(args);
    ret = webview_cef::PluginValue(val);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_FLOAT:{
    double val = fl_value_get_float(args);
    ret = webview_cef::PluginValue(val);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_STRING:{
    const gchar* val = fl_value_get_string(args);
    ret = webview_cef::PluginValue(val);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_UINT8_LIST:{
    size_t len = fl_value_get_length(args);
    const uint8_t* val = fl_value_get_uint8_list(args);
    std::vector<uint8_t> vec(val, val + len);
    ret = webview_cef::PluginValue(vec);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_INT32_LIST:{
    size_t len = fl_value_get_length(args);
    const int32_t* val = fl_value_get_int32_list(args);
    std::vector<int32_t> vec(val, val + len);
    ret = webview_cef::PluginValue(vec);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_INT64_LIST:{
    size_t len = fl_value_get_length(args);
    const int64_t* val = fl_value_get_int64_list(args);
    std::vector<int64_t> vec(val, val + len);
    ret = webview_cef::PluginValue(vec);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_FLOAT32_LIST:{
    size_t len = fl_value_get_length(args);
    const float* val = fl_value_get_float32_list(args);
    std::vector<float> vec(val, val + len);
    ret = webview_cef::PluginValue(vec);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_FLOAT_LIST:{
    size_t len = fl_value_get_length(args);
    const double* val = fl_value_get_float_list(args);
    std::vector<double> vec(val, val + len);
    ret = webview_cef::PluginValue(vec);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_LIST:{
    webview_cef::PluginValueList list;
    for (size_t i = 0; i < fl_value_get_length (args); i++) {
      FlValue *child = fl_value_get_list_value (args, i);
      list.push_back(encode_flvalue_to_pluginvalue(child));
    }
    ret = webview_cef::PluginValue(list);
    break;
  }
  case FlValueType::FL_VALUE_TYPE_MAP:{
    webview_cef::PluginValueMap map;
    for (size_t i = 0; i < fl_value_get_length (args); i++) {
      FlValue *key = fl_value_get_map_key (args, i);
      FlValue *value = fl_value_get_map_value (args, i);
      map[encode_flvalue_to_pluginvalue(key)] = encode_flvalue_to_pluginvalue(value);
    }
    ret = webview_cef::PluginValue(map);
    break;
  }
  default:
    break;
  }
  return ret;
}

// Called when a method call is received from Flutter.
static void webview_cef_plugin_handle_method_call(
    WebviewCefPlugin *self,
    FlMethodCall *method_call)
{
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);
  webview_cef::PluginValue encodeArgs = encode_flvalue_to_pluginvalue(args);
  webview_cef::PluginValue responseArgs;
  int ret = webview_cef::HandleMethodCall(method, &encodeArgs, &responseArgs);
  if (ret > 0){
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(encode_pluginvalue_to_flvalue(&responseArgs)));
  }
  else if (ret < 0){
    response = FL_METHOD_RESPONSE(fl_method_error_response_new("error", "error", encode_pluginvalue_to_flvalue(&responseArgs)));
  }
  else{
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

static void webview_cef_plugin_dispose(GObject *object)
{
  G_OBJECT_CLASS(webview_cef_plugin_parent_class)->dispose(object);
}

static void webview_cef_plugin_class_init(WebviewCefPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = webview_cef_plugin_dispose;
}

static void webview_cef_plugin_init(WebviewCefPlugin *self) {}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  WebviewCefPlugin *plugin = WEBVIEW_CEF_PLUGIN(user_data);
  webview_cef_plugin_handle_method_call(plugin, method_call);
}

void webview_cef_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  WebviewCefPlugin *plugin = WEBVIEW_CEF_PLUGIN(
      g_object_new(webview_cef_plugin_get_type(), nullptr));

  texture_register = fl_plugin_registrar_get_texture_registrar(registrar);
  fl_texture_registrar_register_texture(texture_register, FL_TEXTURE(m_texture));
  webview_cef::setTextureId((int64_t)m_texture);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "webview_cef",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}

FLUTTER_PLUGIN_EXPORT void initCEFProcesses(int argc, char** argv)
{
  CefMainArgs main_args(argc, argv);
  webview_cef::initCEFProcesses(main_args);
}