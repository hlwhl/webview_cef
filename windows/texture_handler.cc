#include "texture_handler.h"

TextureHandler::TextureHandler(flutter::TextureRegistrar* texture_registrar) {
    texture_registrar_ = texture_registrar;
    m_texture_ = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture([this](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
            auto buffer = pixel_buffer.get();
            // Only lock the mutex if the buffer is not null
            // (to ensure the release callback gets called)
            if (buffer) {
                // Gets unlocked in the FlutterDesktopPixelBuffer's release callback.
                buffer_mutex_.lock();
            }
            return buffer;
        })
    );
    texture_id_ = texture_registrar->RegisterTexture(m_texture_.get());
}

TextureHandler::~TextureHandler() {
    texture_registrar_->UnregisterTexture(texture_id_);
    m_texture_ = nullptr;
    pixel_buffer = nullptr;
    backing_pixel_buffer = nullptr;
}

void TextureHandler::onPaintCallback(const void* buffer, int32_t width, int32_t height) {
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

    TextureHandler::SwapBufferFromBgraToRgba((void*)pixel_buffer->buffer, buffer, width, height);
    texture_registrar_->MarkTextureFrameAvailable(texture_id_);
};

void TextureHandler::SwapBufferFromBgraToRgba(void* _dest, const void* _src, int width, int height) {
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