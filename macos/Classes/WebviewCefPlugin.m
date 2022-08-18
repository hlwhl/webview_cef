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
    
    [CefWrapper init];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        NSOperatingSystemVersion systemVer =[[NSProcessInfo processInfo] operatingSystemVersion];
        NSString *systemVersion = [NSString stringWithFormat:@"%ld.%ld.%ld",
                                   (long)systemVer.majorVersion, (long)systemVer.minorVersion, (long)systemVer.patchVersion];
        result([@"macOS " stringByAppendingString:systemVersion]);
    }
    else if([@"init" isEqualToString:call.method]){
        [CefWrapper startCef];
        result([NSNumber numberWithLong:textureId]);
    }
    else if([@"setScrollDelta" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *deltaY = [_arg objectAtIndex:1];
        int delta = [deltaY intValue];
        if(delta > 0) {
            [CefWrapper scrollDown];
        } else {
            [CefWrapper scrollUp];
        }
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
    else if([@"setSize" isEqualToString:call.method]){
        NSArray<NSNumber *> *_arg = call.arguments;
        NSNumber *width = [_arg objectAtIndex:0];
        NSNumber *height = [_arg objectAtIndex:1];
        [CefWrapper sizeChanged:[width intValue] height:[height intValue]];
        result(nil);
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}
@end
