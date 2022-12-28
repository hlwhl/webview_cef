#include <flutter/plugin_registrar_windows.h>

#include <mutex>

class TextureHandler {

private:
    flutter::TextureRegistrar* texture_registrar_;
	int64_t texture_id_ = -1;
	std::shared_ptr<FlutterDesktopPixelBuffer> pixel_buffer;
	std::unique_ptr<uint8_t> backing_pixel_buffer;
	std::mutex buffer_mutex_;
	std::unique_ptr<flutter::TextureVariant> m_texture_;

    static void SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height);

public:
    TextureHandler(flutter::TextureRegistrar* texture_registrar);
    ~TextureHandler();

    int64_t texture_id() const { return texture_id_; }

    void onPaintCallback(const void* buffer, int32_t width, int32_t height);
};
