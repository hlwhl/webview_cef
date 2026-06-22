//
//  WebviewCefTexture.m
//  Pods-Runner
//
//  Created by Hao Linwei on 2022/8/18.
//

#import "WebviewCefTexture.h"
#import <Foundation/Foundation.h>

typedef void(^RetainSelfBlock)(void);

@implementation WebviewCefTexture

- (id) init {
    self = [super init];
    if (self) {
        _lock = dispatch_semaphore_create(1);
        // For the GPU zero-copy path: a system Metal device + command queue used
        // to blit CEF's shared IOSurface into our own buffer each frame.
        _metalDevice = MTLCreateSystemDefaultDevice();
        _metalQueue = [_metalDevice newCommandQueue];
    }
    return self;
}

- (void)onFrame:(const void *)buffer width:(int64_t)width height:(int64_t)height{
    NSDictionary* dic = @{
        (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
        (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
        (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
    };
            
    static CVPixelBufferRef buf = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault,  width,
                                height, kCVPixelFormatType_32BGRA,
                                (__bridge CFDictionaryRef)dic, &buf);
            
    //copy data
    CVPixelBufferLockBaseAddress(buf, 0);
    char *copyBaseAddress = (char *) CVPixelBufferGetBaseAddress(buf);
            
    //MUST align pixel to _pixelBuffer. Otherwise cause render issue. see https://www.codeprintr.com/thread/6563066.html about 16 bytes align
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buf, 0);
    char* src = (char*) buffer;
    int actureRowSize = width * 4;
    for(int line = 0; line < height; line++) {
        memcpy(copyBaseAddress, src, actureRowSize);
        src += actureRowSize;
        copyBaseAddress += bytesPerRow;
    }
    CVPixelBufferUnlockBaseAddress(buf, 0);
            
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if(_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = buf;
    dispatch_semaphore_signal(_lock);
}

// (Re)create the destination buffer pool when the frame size changes. The pool
// recycles our own IOSurface-backed CVPixelBuffers (no per-frame allocation),
// and never vends a buffer Flutter is still holding, so there is no read/write
// race on our side.
- (BOOL)ensurePoolForWidth:(size_t)w height:(size_t)h {
    if (_pool && _poolWidth == w && _poolHeight == h) {
        return YES;
    }
    if (_pool) {
        CVPixelBufferPoolRelease(_pool);
        _pool = NULL;
    }
    NSDictionary* pbAttrs = @{
        (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        (__bridge NSString*)kCVPixelBufferWidthKey : @(w),
        (__bridge NSString*)kCVPixelBufferHeightKey : @(h),
        (__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
        (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
    };
    if (CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL,
            (__bridge CFDictionaryRef)pbAttrs, &_pool) != kCVReturnSuccess) {
        _pool = NULL;
        return NO;
    }
    _poolWidth = w;
    _poolHeight = h;
    return YES;
}

- (id<MTLTexture>)metalTextureFromSurface:(IOSurfaceRef)surface
                                    width:(size_t)w
                                   height:(size_t)h
                                    usage:(MTLTextureUsage)usage {
    MTLTextureDescriptor* desc =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                           width:w
                                                          height:h
                                                       mipmapped:NO];
    desc.usage = usage;
    desc.storageMode = MTLStorageModeShared;  // IOSurface-backed
    return [_metalDevice newTextureWithDescriptor:desc iosurface:surface plane:0];
}

- (void)onAcceleratedFrame:(IOSurfaceRef)surface {
    if (!surface || _metalDevice == nil) {
        return;
    }
    size_t w = IOSurfaceGetWidth(surface);
    size_t h = IOSurfaceGetHeight(surface);
    if (w == 0 || h == 0) {
        return;
    }

    // Flutter's macOS texture pipeline only accepts 32BGRA; CEF vends BGRA on
    // macOS in practice. Warn once (don't silently mis-render) if that changes.
    static BOOL warnedFormat = NO;
    OSType fmt = IOSurfaceGetPixelFormat(surface);
    if (fmt != kCVPixelFormatType_32BGRA && !warnedFormat) {
        warnedFormat = YES;
        NSLog(@"[webview_cef] unexpected accelerated-paint IOSurface format 0x%x "
              @"(expected BGRA); colors may be wrong", (unsigned int)fmt);
    }

    if (![self ensurePoolForWidth:w height:h]) {
        return;
    }
    CVPixelBufferRef dst = NULL;
    if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pool, &dst) != kCVReturnSuccess
        || dst == NULL) {
        return;
    }
    IOSurfaceRef dstSurface = CVPixelBufferGetIOSurface(dst);
    if (dstSurface == NULL) {
        CVPixelBufferRelease(dst);
        return;
    }

    // CEF's contract: the source IOSurface is pool-owned and recycled once this
    // callback returns, so it MUST be copied into a client-owned texture here
    // (cef_render_handler.h). A GPU blit does that GPU-resident — far cheaper
    // than the old software path's full-frame CPU memcpy, and with no tearing
    // race since CEF never touches our destination buffer.
    id<MTLTexture> srcTex = [self metalTextureFromSurface:surface width:w height:h
                                                    usage:MTLTextureUsageShaderRead];
    id<MTLTexture> dstTex = [self metalTextureFromSurface:dstSurface width:w height:h
                                                    usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget];
    if (srcTex == nil || dstTex == nil) {
        CVPixelBufferRelease(dst);
        return;
    }

    id<MTLCommandBuffer> cmd = [_metalQueue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [cmd blitCommandEncoder];
    [blit copyFromTexture:srcTex
              sourceSlice:0
              sourceLevel:0
             sourceOrigin:MTLOriginMake(0, 0, 0)
               sourceSize:MTLSizeMake(w, h, 1)
                toTexture:dstTex
         destinationSlice:0
         destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blit endEncoding];
    [cmd commit];
    // Block until the copy completes: CEF reclaims the source surface as soon as
    // this callback returns, so the read must finish first. The blit is tiny.
    [cmd waitUntilCompleted];

    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = dst;
    dispatch_semaphore_signal(_lock);
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    _pixelBufferTemp = _pixelBuffer;
    CVPixelBufferRetain(_pixelBufferTemp);
    dispatch_semaphore_signal(_lock);
    return _pixelBufferTemp;
}

- (void)dealloc {
    // The most recent frame's buffer is only released when the next frame
    // replaces it; without this it leaks on browser close — and in the GPU path
    // each leaked CVPixelBuffer also pins an IOSurface (GPU memory / pool slot),
    // so repeated create/close cycles would accumulate. (_pixelBufferTemp just
    // aliases _pixelBuffer; the engine owns the retain handed out by
    // copyPixelBuffer, so don't release it here.)
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
    if (_pool) {
        CVPixelBufferPoolRelease(_pool);
        _pool = NULL;
    }
    dispatch_semaphore_signal(_lock);
}

@end
