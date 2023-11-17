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

+ (void)setMethodChannel: (FlutterMethodChannel*)channel;
+ (FlutterResult) handleMethodCallWrapper: (FlutterMethodCall*)call;

@end

#endif /* CefWrapper_h */
