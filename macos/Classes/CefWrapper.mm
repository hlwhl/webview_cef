//
//  CefWrapper.m
//  Pods-Runner
//
//  Created by Hao Linwei on 2022/8/18.
//

#import "CefWrapper.h"
#import <Foundation/Foundation.h>
#import "include/wrapper/cef_library_loader.h"
#import "include/cef_app.h"
#import "simple_app.h"

#include <thread>

CefRefPtr<SimpleHandler> handler(new SimpleHandler(false));
CefRefPtr<SimpleApp> app(new SimpleApp(handler));
CefMainArgs mainArgs;

NSObject<FlutterTextureRegistry>* tr;

static NSTimer* _timer;
static CVPixelBufferRef buf_cache;
static CVPixelBufferRef buf_temp;
dispatch_semaphore_t lock = dispatch_semaphore_create(1);

int64_t textureId;

@implementation CefWrapper

+ (void)init {
    CefScopedLibraryLoader loader;
    
    if(!loader.LoadInMain()) {
        printf("load cef err");
    }
    
    CefMainArgs main_args;
    CefExecuteProcess(main_args, nullptr, nullptr);
}

+ (void)doMessageLoopWork {
    CefDoMessageLoopWork();
}

+ (void)startCef {
    textureId = [tr registerTexture:[CefWrapper alloc]];
    handler.get()->onPaintCallback = [](const void* buffer, int32_t width, int32_t height) {
        NSDictionary* dic = @{
            (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{},
            (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
            (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
        };
        static CVPixelBufferRef buf = NULL;
        CVPixelBufferCreate(kCFAllocatorDefault, width,
                            height, kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)dic, &buf);
        CVPixelBufferLockBaseAddress(buf, 0);
        void *copyBaseAddress = CVPixelBufferGetBaseAddress(buf);
        memcpy(copyBaseAddress, buffer, width * height * 4);
        CVPixelBufferUnlockBaseAddress(buf, 0);
        
        dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
        if(buf_cache) {
            CVPixelBufferRelease(buf_cache);
        }
        buf_cache = buf;
        dispatch_semaphore_signal(lock);
        [tr textureFrameAvailable:textureId];
    };
    CefSettings cefs;
    cefs.windowless_rendering_enabled = true;
    CefInitialize(mainArgs, cefs, app.get(), nullptr);
    _timer = [NSTimer timerWithTimeInterval:0.016f target:self selector:@selector(doMessageLoopWork) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer: _timer forMode:NSRunLoopCommonModes];
}

+ (void)scrollUp {
    handler.get()->scrollUp();
}

+(void)scrollDown {
    handler.get()->scrollDown();
}

+ (void)cursorClickUp:(int)x y:(int)y {
    handler.get()->cursorClick(x, y, true);
}

+ (void)cursorClickDown:(int)x y:(int)y {
    handler.get()->cursorClick(x, y, false);
}

+ (void)sizeChanged:(int)width height:(int)height {
    handler.get()->changeSize(width, height);
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    buf_temp = buf_cache;
    CVPixelBufferRetain(buf_temp);
    dispatch_semaphore_signal(lock);
    return buf_temp;
}

@end
