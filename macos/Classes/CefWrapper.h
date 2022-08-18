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
extern int64_t textureId;

@interface CefWrapper : NSObject<FlutterTexture>

+ (void) init;

+ (void) startCef;

+ (void) scrollUp;

+ (void) scrollDown;

+ (void) cursorClickUp: (int)x y:(int)y;

+ (void) cursorClickDown: (int)x y:(int)y;

+ (void) sizeChanged: (int)width height:(int)height;

@end

#endif /* CefWrapper_h */
