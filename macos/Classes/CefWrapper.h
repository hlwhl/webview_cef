//
//  CefWrapper.h
//  Pods
//
//  Created by Hao Linwei on 2022/8/18.
//

#ifndef CefWrapper_h
#define CefWrapper_h
#import <FlutterMacOS/FlutterMacOS.h>

extern NSObject<FlutterTextureRegistry>* tr;
extern CGFloat scaleFactor;

@interface CefWrapper : NSObject<FlutterTexture>
{
    int64_t _textureId;
    CVPixelBufferRef _pixelBuffer;
    CVPixelBufferRef _pixelBufferTemp;
    dispatch_semaphore_t _lock;
}
@property(nonatomic) int64_t textureId;

+ (void)setMethodChannel: (FlutterMethodChannel*)channel;
+ (FlutterResult) handleMethodCallWrapper: (FlutterMethodCall*)call;

@end

#endif /* CefWrapper_h */
