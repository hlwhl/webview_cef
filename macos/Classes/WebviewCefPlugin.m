#import "WebviewCefPlugin.h"

@implementation WebviewCefPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"webview_cef"
            binaryMessenger:[registrar messenger]];
    
    WebviewCefPlugin *instance = [[WebviewCefPlugin alloc] init];
    
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {

  if ([@"getPlatformVersion" isEqualToString:call.method]) {
      NSOperatingSystemVersion systemVer =[[NSProcessInfo processInfo] operatingSystemVersion];
      NSString *systemVersion = [NSString stringWithFormat:@"%ld.%ld.%ld",
                                 (long)systemVer.majorVersion, (long)systemVer.minorVersion, (long)systemVer.patchVersion];
      result([@"macOS " stringByAppendingString:systemVersion]);
  }
  else {
    result(FlutterMethodNotImplemented);
  }
}
@end
