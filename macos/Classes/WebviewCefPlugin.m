#import "WebviewCefPlugin.h"
#import "CefWrapper.h"

@implementation WebviewCefPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"webview_cef"
                                     binaryMessenger:[registrar messenger]];
    
    WebviewCefPlugin *instance = [[WebviewCefPlugin alloc] init];
    
    [registrar addMethodCallDelegate:instance channel:channel];
    [CefWrapper setMethodChannel:channel];
    
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
        NSString *userAgent = call.arguments;
        [CefWrapper init];
        [CefWrapper startCef:userAgent];
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
    else if([@"openDevTools" isEqualToString:call.method]){
        [CefWrapper openDevTools];
        result(nil);
    }
    else if ([@"imeSetComposition" isEqualToString:call.method]) {
        NSArray<NSString *> *_arg = call.arguments;
        NSString * text = [_arg objectAtIndex:0];
        [CefWrapper imeSetComposition:text];
        result(nil);
	} 
    else if ([@"imeCommitText" isEqualToString:call.method]) {
        NSArray<NSString *> *_arg = call.arguments;
        NSString * text = [_arg objectAtIndex:0];
        [CefWrapper imeCommitText:text];
        result(nil);
	} 
    else if ([@"setClientFocus" isEqualToString:call.method]) {
        NSArray<NSString *> *_arg = call.arguments;
        NSString * focus = [_arg objectAtIndex:0];
        [CefWrapper setClientFocus:[focus boolValue]];
        result(nil);
	}
    else if([@"setCookie" isEqualToString:call.method]){
        NSArray<NSString *> *_arg = call.arguments;
        NSString * domain = [_arg objectAtIndex:0];
        NSString * key = [_arg objectAtIndex:1];
        NSString * value = [_arg objectAtIndex:2];
        [CefWrapper setCookie:domain key:key value:value];
        result(nil);
    }
    else if ([@"deleteCookie" isEqualToString:call.method]) {
        NSArray<NSString *> *_arg = call.arguments;
        NSString * domain = [_arg objectAtIndex:0];
        NSString * key = [_arg objectAtIndex:1];
        [CefWrapper deleteCookie:domain key:key];
        result(nil);
    }
    else if ([@"visitAllCookies" isEqualToString:call.method]) {
        [CefWrapper visitAllCookies];
        result(nil);
    }
    else if ([@"visitUrlCookies" isEqualToString:call.method]) {
        NSArray<NSString *> *_arg = call.arguments;
        NSString * domain = [_arg objectAtIndex:0];
        NSString * isHttpOnly = [_arg objectAtIndex:1];
        [CefWrapper visitUrlCookies:domain isHttpOnly:[isHttpOnly boolValue]];
        result(nil);
    }
    else if ([@"setJavaScriptChannels" isEqualToString:call.method])  {
        NSArray<NSArray *> *_arg = call.arguments;
        NSArray * channels = [_arg objectAtIndex:0];
        [CefWrapper setJavaScriptChannels:channels];
        result(nil);
    }
    else if ([@"sendJavaScriptChannelCallBack" isEqualToString:call.method])  {
        NSArray<NSString *> *_arg = call.arguments;
        NSString * error = [_arg objectAtIndex:0];
        NSString * ret = [_arg objectAtIndex:1];
        NSString * callbackId = [_arg objectAtIndex:2];
        NSString * frameId = [_arg objectAtIndex:3];
        [CefWrapper sendJavaScriptChannelCallBack:[error boolValue]  result:ret callbackId:callbackId frameId:frameId];
        result(nil);
    }
    else if ([@"executeJavaScript" isEqualToString:call.method])  {
        NSArray<NSString *> *_arg = call.arguments;
        NSString * code = [_arg objectAtIndex:0];
        [CefWrapper executeJavaScript:code];
        result(nil);
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}
@end
