#ifndef WEBVIEW_CEF_TEXTURE_H_
#define WEBVIEW_CEF_TEXTURE_H_

#include <flutter/texture_registrar.h>
#include <flutter_texture_registrar.h>

#include <cstdint>
#include <cstring>
#include <memory>
#include <mutex>

struct WebviewCefTexture {
  uint8_t* buffer = nullptr;
  uint32_t width = 0;
  uint32_t height = 0;
  int64_t textureId = 0;

  FlutterDesktopPixelBuffer pixel_buffer = {};

  std::unique_ptr<flutter::TextureVariant> texture_variant;
  std::mutex mutex;

  WebviewCefTexture() {
    texture_variant = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture(
            [this](size_t w, size_t h) -> const FlutterDesktopPixelBuffer* {
              std::lock_guard<std::mutex> lock(mutex);
              pixel_buffer.buffer = buffer;
              pixel_buffer.width = width;
              pixel_buffer.height = height;
              return &pixel_buffer;
            }));
  }

  ~WebviewCefTexture() {
    delete[] buffer;
  }
};

#endif  // WEBVIEW_CEF_TEXTURE_H_
