#import "WebviewCefPlugin.h"
#import "CefWrapper.h"

@implementation WebviewCefPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"webview_cef"
                                     binaryMessenger:[registrar messenger]];
    
    WebviewCefPlugin *instance = [[WebviewCefPlugin alloc] init];
    
    [registrar addMethodCallDelegate:instance channel:channel];
    
    tr = registrar.textures;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        NSOperatingSystemVersion systemVer =[[NSProcessInfo processInfo] operatingSystemVersion];
        NSString *systemVersion = [NSString stringWithFormat:@"%ld.%ld.%ld",
                                   (long)systemVer.majorVersion, (long)systemVer.minorVersion, (long)systemVer.patchVersion];
        result([@"macOS " stringByAppendingString:systemVersion]);
    }
    else if([@"init" isEqualToString:call.method]){
        [CefWrapper init];
        [CefWrapper startCef];
        result([NSNumber numberWithLong:textureId]);
    }
    else if([@"loadUrl" isEqualToString:call.method]){
        NSString * url = call.arguments;
        [CefWrapper loadUrl:url];
        result(nil);
    }
    else if([@"setScrollDelta" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *x = [_arg objectAtIndex:0];
        NSNumber *y = [_arg objectAtIndex:1];
        NSNumber *deltaX = [_arg objectAtIndex:2];
        NSNumber *deltaY = [_arg objectAtIndex:3];
        [CefWrapper sendScrollEvent:[x intValue] y:[y intValue] deltaX:[deltaX intValue] deltaY:[deltaY intValue]];
        result(nil);
    }
    else if([@"cursorClickUp" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *x = [_arg objectAtIndex:0];
        NSNumber *y = [_arg objectAtIndex:1];
        [CefWrapper cursorClickUp:[x intValue] y:[y intValue]];
        result(nil);
    }
    else if([@"cursorClickDown" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *x = [_arg objectAtIndex:0];
        NSNumber *y = [_arg objectAtIndex:1];
        [CefWrapper cursorClickDown:[x intValue] y:[y intValue]];
        result(nil);
    }
    else if([@"cursorMove" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *x = [_arg objectAtIndex:0];
        NSNumber *y = [_arg objectAtIndex:1];
        [CefWrapper cursorMove:[x intValue] y:[y intValue] dragging: false];
        result(nil);
    }
    else if([@"cursorDragging" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *x = [_arg objectAtIndex:0];
        NSNumber *y = [_arg objectAtIndex:1];
        [CefWrapper cursorMove:[x intValue] y:[y intValue] dragging: true];
        result(nil);
    }
    else if([@"setSize" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *dpi = [_arg objectAtIndex:0];
        NSNumber *width = [_arg objectAtIndex:1];
        NSNumber *height = [_arg objectAtIndex:2];
        [CefWrapper sizeChanged: [dpi floatValue] width:[width intValue] height:[height intValue]];
        result(nil);
    }
    else if([@"goForward" isEqualToString:call.method]){
        [CefWrapper goForward];
        result(nil);
    }
    else if([@"goBack" isEqualToString:call.method]){
        [CefWrapper goBack];
        result(nil);
    }
    else if([@"reload" isEqualToString:call.method]){
        [CefWrapper reload];
        result(nil);
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}
@end
