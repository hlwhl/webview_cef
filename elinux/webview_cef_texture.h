#ifndef WEBVIEW_CEF_TEXTURE_H_
#define WEBVIEW_CEF_TEXTURE_H_

#include <flutter_elinux/flutter_elinux.h>

struct WebviewCefTexture {
    FlPixelBufferTexture parent_instance;
    uint8_t *buffer = nullptr;
    uint32_t width = 0;
    uint32_t height = 0;
};

struct WebviewCefTextureClass {
    FlPixelBufferTextureClass parent_class;
};

G_DEFINE_TYPE(WebviewCefTexture,
              webview_cef_texture,
              fl_pixel_buffer_texture_get_type())

#define WEBVIEW_CEF_TEXTURE(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST((obj), webview_cef_texture_get_type(), WebviewCefTexture))

static gboolean webview_cef_texture_copy_pixels(FlPixelBufferTexture *texture,
                                                const uint8_t **out_buffer,
                                                uint32_t *width,
                                                uint32_t *height,
                                                GError **error) {
    WebviewCefTexture *_texture = WEBVIEW_CEF_TEXTURE(texture);
    if (_texture == nullptr) {
        return TRUE;
    }
    *out_buffer = _texture->buffer;
    *width = _texture->width;
    *height = _texture->height;
    return TRUE;
}

static WebviewCefTexture* webview_cef_texture_new() {
    return WEBVIEW_CEF_TEXTURE(g_object_new(webview_cef_texture_get_type(), nullptr));
}

static void webview_cef_texture_finalize(GObject *obj) {
    WebviewCefTexture *self = WEBVIEW_CEF_TEXTURE(obj);
    delete[] self->buffer;
    G_OBJECT_CLASS(webview_cef_texture_parent_class)->finalize(obj);
}

static void webview_cef_texture_class_init(WebviewCefTextureClass *klass) {
    FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = webview_cef_texture_copy_pixels;
    G_OBJECT_CLASS(klass)->finalize = webview_cef_texture_finalize;
}

static void webview_cef_texture_init(WebviewCefTexture *self) {}

#endif // WEBVIEW_CEF_TEXTURE_H_
