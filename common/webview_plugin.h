#ifndef WEBVIEW_PLUGIN_H
#define WEBVIEW_PLUGIN_H

#include <functional>
#include <any>
#include <cassert>
#include <cstdint>
#include <map>
#include <string>
#include <utility>
#include <variant>
#include <vector>
#include <../third/cef/include/internal/cef_types_wrappers.h>
#include <../third/cef/include/internal/cef_linux.h>

namespace webview_cef {

    class PluginValue;

    using PluginValueList = std::vector<PluginValue>;
    using PluginValueMap = std::map<PluginValue,PluginValue>;
    using PluginValueVariant = std::variant<std::monostate,
                                           bool,
                                           int32_t,
                                           int64_t,
                                           double,
                                           std::string,
                                           std::vector<uint8_t>,
                                           std::vector<int32_t>,
                                           std::vector<int64_t>,
                                           std::vector<float>,
                                           std::vector<double>,
                                           PluginValueList,
                                           PluginValueMap>;

    class PluginValue: public PluginValueVariant
    {
    public:
        using super = PluginValueVariant;
        using super::super;
        using super::operator=;

        explicit PluginValue() = default;

        explicit PluginValue(const char* str) : super(std::string(str)) {}
        PluginValue& operator=(const char* other) {
            *this = std::string(other);
            return *this;
        }

        template <class T>
        constexpr explicit PluginValue(T&& t) noexcept : super(t) {}

        bool IsNull() const { return std::holds_alternative<std::monostate>(*this); }

        int64_t LongValue() const {
            if(std::holds_alternative<int32_t>(*this)){
                return std::get<int32_t>(*this);
            }
            return std::get<int64_t>(*this);
        }
        
    };

    void initCEFProcesses(CefMainArgs args);
    void startCEF();
    void sendKeyEvent(CefKeyEvent ev);
    int HandleMethodCall(std::string name, PluginValue* values, PluginValue* response);
    void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height);
    void setPaintCallBack(std::function<void(const void*, int32_t , int32_t )> callback);
    void setInvokeMethodFunc(std::function<void(std::string, PluginValue*)> func);
}

#endif //WEBVIEW_PLUGIN_H