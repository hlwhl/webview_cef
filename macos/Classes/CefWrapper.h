//
//  CefWrapper.h
//  Pods
//
//  Created by Hao Linwei on 2022/8/18.
//

#ifndef CefWrapper_h
#define CefWrapper_h
#import <FlutterMacOS/FlutterMacOS.h>

extern NSMapTable* webviewPlugins;

@interface CefWrapper : NSObject

@property(nonatomic) NSObject<FlutterTextureRegistry>* textureRegistry;
@property(nonatomic) FlutterMethodChannel* channel;

- (void)handleMethodCallWrapper: (FlutterMethodCall*)call result:(FlutterResult)result;

@end

#endif /* CefWrapper_h */
