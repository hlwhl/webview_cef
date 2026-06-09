//
//  WebviewCefTexture.h
//  Pods
//
//  Created by Hao Linwei on 2022/8/18.
//

#ifndef WebviewCefTexture_h
#define WebviewCefTexture_h
#import <FlutterMacOS/FlutterMacOS.h>

@interface WebviewCefTexture : NSObject<FlutterTexture>
{
    CVPixelBufferRef _pixelBuffer;
    CVPixelBufferRef _pixelBufferTemp;
    dispatch_semaphore_t _lock;
}

- (void)onFrame:(const void *)buffer width:(int64_t)width height:(int64_t)height;

@end

#endif /* WebviewCefTexture_h */
