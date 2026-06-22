//
//  WebviewCefTexture.h
//  Pods
//
//  Created by Hao Linwei on 2022/8/18.
//

#ifndef WebviewCefTexture_h
#define WebviewCefTexture_h
#import <FlutterMacOS/FlutterMacOS.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>

@interface WebviewCefTexture : NSObject<FlutterTexture>
{
    CVPixelBufferRef _pixelBuffer;
    CVPixelBufferRef _pixelBufferTemp;
    dispatch_semaphore_t _lock;
    // GPU-path state: a Metal blit copies CEF's pool-owned IOSurface into our
    // own pooled CVPixelBuffer (CEF recycles its surface after the callback).
    id<MTLDevice> _metalDevice;
    id<MTLCommandQueue> _metalQueue;
    CVPixelBufferPoolRef _pool;
    size_t _poolWidth;
    size_t _poolHeight;
}

// Software path: CEF's OnPaint CPU buffer (copied into a CVPixelBuffer).
- (void)onFrame:(const void *)buffer width:(int64_t)width height:(int64_t)height;

// GPU zero-copy path: CEF's OnAcceleratedPaint IOSurface, wrapped as a
// CVPixelBuffer and handed straight to Flutter (no CPU copy / per-frame alloc).
- (void)onAcceleratedFrame:(IOSurfaceRef)surface;

@end

#endif /* WebviewCefTexture_h */
