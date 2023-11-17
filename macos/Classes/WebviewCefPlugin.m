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
    result([CefWrapper handleMethodCallWrapper:call]);
}
@end
