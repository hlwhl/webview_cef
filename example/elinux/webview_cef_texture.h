#ifndef WEBVIEW_CEF_TEXTURE_H_
#define WEBVIEW_CEF_TEXTURE_H_

#include <flutter/texture_registrar.h>
#include <webview_plugin.h>
#include <mutex>

namespace webview_cef {

class WebviewTextureRenderer : public WebviewTexture {
 public:
  WebviewTextureRenderer(flutter::TextureRegistrar* registrar)
      : registrar_(registrar) {
    texture_ = std::make_unique<flutter::PixelBufferTexture>(
        [this](size_t width, size_t height) -> const FlutterDesktopPixelBuffer* {
          return this->CopyPixelBuffer(width, height);
        });
    texture_id_ = registrar_->RegisterTexture(texture_.get());
  }

  virtual ~WebviewTextureRenderer() {
    registrar_->UnregisterTexture(texture_id_);
  }

  int64_t texture_id() const { return texture_id_; }

  virtual void onFrame(const void* buffer, int32_t width, int32_t height) override {
    std::lock_guard<std::mutex> lock(mutex_);
    if (width_ != width || height_ != height) {
      width_ = width;
      height_ = height;
      const auto size = width * height * 4;
      buffer_.reset(new uint8_t[size]);
    }
    SwapBufferFromBgraToRgba(buffer_.get(), buffer, width, height);
    
    pixel_buffer_.width = width;
    pixel_buffer_.height = height;
    pixel_buffer_.buffer = buffer_.get();
    
    registrar_->MarkTextureFrameAvailable(texture_id_);
  }

 private:
  const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t width, size_t height) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!buffer_) {
      return nullptr;
    }
    return &pixel_buffer_;
  }

  flutter::TextureRegistrar* registrar_;
  std::unique_ptr<flutter::PixelBufferTexture> texture_;
  int64_t texture_id_;

  std::mutex mutex_;
  std::unique_ptr<uint8_t[]> buffer_;
  int32_t width_ = 0;
  int32_t height_ = 0;
  FlutterDesktopPixelBuffer pixel_buffer_ = {nullptr, 0, 0};
};

}  // namespace webview_cef

#endif  // WEBVIEW_CEF_TEXTURE_H_