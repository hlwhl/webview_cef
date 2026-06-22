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

- (void)onAcceleratedFrame:(IOSurfaceRef)surface {
    if (!surface) {
        return;
    }
    // Wrap CEF's shared IOSurface directly — no CPU copy, no swizzle (the
    // surface is already BGRA on the GPU), no per-frame allocation. The surface
    // is owned by CEF's pool and recycled after OnAcceleratedPaint returns;
    // CVPixelBufferCreateWithIOSurface retains it, and the double buffer below
    // keeps the previous frame alive until the next one arrives, which (with
    // CEF's multi-surface pool) covers Flutter's one-frame read latency.
    NSDictionary* attrs = @{
        (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
        (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
    };
    CVPixelBufferRef buf = NULL;
    CVReturn ret = CVPixelBufferCreateWithIOSurface(
        kCFAllocatorDefault, surface, (__bridge CFDictionaryRef)attrs, &buf);
    if (ret != kCVReturnSuccess || buf == NULL) {
        return;
    }

    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = buf;
    dispatch_semaphore_signal(_lock);
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    _pixelBufferTemp = _pixelBuffer;
    CVPixelBufferRetain(_pixelBufferTemp);
    dispatch_semaphore_signal(_lock);
    return _pixelBufferTemp;
}

@end
