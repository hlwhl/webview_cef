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

@interface WebviewCefTexture : NSObject<FlutterTexture>
{
    CVPixelBufferRef _pixelBuffer;
    CVPixelBufferRef _pixelBufferTemp;
    dispatch_semaphore_t _lock;
}

// Software path: CEF's OnPaint CPU buffer (copied into a CVPixelBuffer).
- (void)onFrame:(const void *)buffer width:(int64_t)width height:(int64_t)height;

// GPU zero-copy path: CEF's OnAcceleratedPaint IOSurface, wrapped as a
// CVPixelBuffer and handed straight to Flutter (no CPU copy / per-frame alloc).
- (void)onAcceleratedFrame:(IOSurfaceRef)surface;

@end

#endif /* WebviewCefTexture_h */
