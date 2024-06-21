//
//  CefWrapper.m
//  Pods-Runner
//
//  Created by Hao Linwei on 2022/8/18.
//

#import "CefWrapper.h"
#import "WebviewCefTexture.h"
#import <Foundation/Foundation.h>
#import "include/cef_base.h"
#import "../../common/webview_app.h"
#import "../../common/webview_handler.h"
#import "../../common/webview_cookieVisitor.h"
#import "../../common/webview_js_handler.h"
#import "../../common/webview_plugin.h"
#import "../../common/webview_value.h"
#include <thread>

static NSTimer* _timer;
static BOOL isCefProcessInit = NO;
static BOOL isCefMessageLoop = NO;
NSMapTable* webviewPlugins = [NSMapTable weakToWeakObjectsMapTable];

@implementation CefWrapper{
    std::shared_ptr<webview_cef::WebviewPlugin> _plugin;
}

class WebviewTextureRenderer : public webview_cef::WebviewTexture {
public:
    WebviewTextureRenderer(NSObject<FlutterTextureRegistry>* registry){
        textureRegistry = registry;
        texture = [[WebviewCefTexture alloc] init];
        textureId = [textureRegistry registerTexture:texture];
    }

    virtual ~WebviewTextureRenderer() {
        [textureRegistry unregisterTexture:textureId];
    }

    virtual void onFrame(const void* buffer, int width, int height) {
        [texture onFrame:buffer width:width height:height];
        [textureRegistry textureFrameAvailable: textureId];
    }

private:
    WebviewCefTexture* texture;
    NSObject<FlutterTextureRegistry>* textureRegistry;
};

+ (NSObject *)encode_wvalue_to_flvalue: (WValue*)args {
    WValueType type = webview_value_get_type(args);
    switch(type) {
        case Webview_Value_Type_Bool:
            return [NSNumber numberWithBool:webview_value_get_bool(args)];
        case Webview_Value_Type_Int:
            return [NSNumber numberWithLongLong:webview_value_get_int(args)];
        case Webview_Value_Type_Float:
            return [NSNumber numberWithFloat:webview_value_get_float(args)];
        case Webview_Value_Type_Double:
            return [NSNumber numberWithDouble:webview_value_get_double(args)];
        case Webview_Value_Type_String:
            return [NSString stringWithUTF8String:webview_value_get_string(args)];
        case Webview_Value_Type_Uint8_List:
            return [NSData dataWithBytes:webview_value_get_uint8_list(args) length:webview_value_get_len(args)];
        case Webview_Value_Type_Int32_List:
            return [NSData dataWithBytes:webview_value_get_int32_list(args) length:webview_value_get_len(args)];
        case Webview_Value_Type_Int64_List:
            return [NSData dataWithBytes:webview_value_get_int64_list(args) length:webview_value_get_len(args)];
        case Webview_Value_Type_Float_List:
            return [NSData dataWithBytes:webview_value_get_float_list(args) length:webview_value_get_len(args)];
        case Webview_Value_Type_Double_List:
            return [NSData dataWithBytes:webview_value_get_double_list(args) length:webview_value_get_len(args)];
        case Webview_Value_Type_List: {
            int64_t len = webview_value_get_len(args);
            NSMutableArray* array = [NSMutableArray arrayWithCapacity:len];
            for(int64_t i = 0; i < len; i++) {
                WValue* item = webview_value_get_list_value(args, i);
                [array addObject:[CefWrapper encode_wvalue_to_flvalue:item]];
            }
            return array;
        }
        case Webview_Value_Type_Map: {
            int64_t len = webview_value_get_len(args);
            NSMutableDictionary* dic = [NSMutableDictionary dictionaryWithCapacity:len];
            for(int i = 0; i < len; i++) {
                WValue *value = webview_value_get_value(args, i);
                WValue *key = webview_value_get_key(args, i);
                NSString *nsKkey = [CefWrapper encode_wvalue_to_flvalue:key];
                if (key != nil && value != nil) {
                    [dic setObject:[CefWrapper encode_wvalue_to_flvalue:value] forKey:nsKkey];
                }
            }
            return dic;
        }
        default:
            return nil;
    }
}

+ (WValue*) encode_flvalue_to_wvalue: (NSObject *)value{
    if([value isKindOfClass:[NSNumber class]]) {
        NSNumber* number = (NSNumber*)value;
        if(strcmp([number objCType], @encode(BOOL)) == 0) {
            return webview_value_new_bool([number boolValue]);
        } else if(strcmp([number objCType], @encode(int)) == 0) {
            return webview_value_new_int([number intValue]);
        } else if(strcmp([number objCType], @encode(float)) == 0) {
            return webview_value_new_float([number floatValue]);
        } else if(strcmp([number objCType], @encode(double)) == 0) {
            return webview_value_new_double([number doubleValue]);
        } else {
            return nil;
        }
    } else if([value isKindOfClass:[NSString class]]) {
        NSString* string = (NSString*)value;
        return webview_value_new_string([string UTF8String]);
    } else if([value isKindOfClass:[NSData class]]) {
        NSData* data = (NSData*)value;
        return webview_value_new_int64_list((int64_t*)data.bytes, (size_t)data.length);
    } else if([value isKindOfClass:[NSArray class]]) {
        NSArray* array = (NSArray*)value;
        int len = (int)array.count;
        WValue* wvalue = webview_value_new_list();
        for(int i = 0; i < len; i++) {
            WValue* item = [CefWrapper encode_flvalue_to_wvalue:array[i]];
            webview_value_append(wvalue, item);
            webview_value_unref(item);
        }
        return wvalue;
    } else if([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dic = (NSDictionary*)value;
        int len = (int)dic.count;
        WValue* wvalue = webview_value_new_map();
        for(int i = 0; i < len; i++) {
            WValue* key = [CefWrapper encode_flvalue_to_wvalue:dic.allKeys[i]];
            WValue* item = [CefWrapper encode_flvalue_to_wvalue:dic.allValues[i]];
            webview_value_set(wvalue, key, item);
            webview_value_unref(key);
            webview_value_unref(item);
        }
        return wvalue;
    } else {
        return nil;
    }
}

+ (BOOL)processKeyboardEvent: (NSEvent*) event {
    CefWrapper *currentPlugin = [webviewPlugins objectForKey:event.window.contentView];
    if(currentPlugin == nil || !currentPlugin->_plugin->getAnyBrowserFocused()){
        return false;
    }
    
    CefKeyEvent keyEvent;
    
    NSString* s = [event characters];
    
    if ([s length] != 0){
        keyEvent.character = [s characterAtIndex:0];
    }

    s = [event charactersIgnoringModifiers];
    if ([s length] > 0){
        keyEvent.unmodified_character = [s characterAtIndex:0];
    }
    
    if ([event type] == NSEventTypeFlagsChanged){
        keyEvent.character = 0;
        keyEvent.unmodified_character = 0;
    }
        
    keyEvent.native_key_code = [event keyCode];
    
    keyEvent.modifiers = [CefWrapper getModifiersForEvent:event];

//    if(keyEvent.native_key_code == 51){
//        keyEvent.character = 0;
//        keyEvent.unmodified_character = 0;
//    }
    if([event type] == NSEventTypeKeyDown){
        keyEvent.type = KEYEVENT_RAWKEYDOWN;
        currentPlugin->_plugin->sendKeyEvent(keyEvent);
        keyEvent.type = KEYEVENT_CHAR;
    }else{
        keyEvent.type = KEYEVENT_KEYUP;
    }

    currentPlugin->_plugin->sendKeyEvent(keyEvent);
    return true;
}

+ (int)getModifiersForEvent:(NSEvent*)event {
    int modifiers = 0;
    
    //Warning:NSEventModifierFlags is support for MacOS 10.12 and after
    if ([event modifierFlags] & NSEventModifierFlagControl){
        modifiers |= EVENTFLAG_CONTROL_DOWN;
    }
    if ([event modifierFlags] & NSEventModifierFlagShift){
        modifiers |= EVENTFLAG_SHIFT_DOWN;
    }
    if ([event modifierFlags] & NSEventModifierFlagOption){
        modifiers |= EVENTFLAG_ALT_DOWN;
    }
    if ([event modifierFlags] & NSEventModifierFlagCommand){
        modifiers |= EVENTFLAG_COMMAND_DOWN;
    }
    if ([event modifierFlags] & NSEventModifierFlagCapsLock){
        modifiers |= EVENTFLAG_CAPS_LOCK_ON;
    }
    if ([event type] == NSEventTypeKeyUp || [event type] == NSEventTypeKeyDown ||
        [event type] == NSEventTypeFlagsChanged) {
        // Only perform this check for key events
        if ([CefWrapper isKeyPadEvent:event]){
            modifiers |= EVENTFLAG_IS_KEY_PAD;
        }
    }
    
    // OS X does not have a modifier for NumLock, so I'm not entirely sure how to
    // set EVENTFLAG_NUM_LOCK_ON;
    //
    // There is no EVENTFLAG for the function key either.
    
    // Mouse buttons
    switch ([event type]) {
        case NSEventTypeLeftMouseDragged:
        case NSEventTypeLeftMouseDown:
        case NSEventTypeLeftMouseUp:
            modifiers |= EVENTFLAG_LEFT_MOUSE_BUTTON;
            break;
        case NSEventTypeRightMouseDragged:
        case NSEventTypeRightMouseDown:
        case NSEventTypeRightMouseUp:
            modifiers |= EVENTFLAG_RIGHT_MOUSE_BUTTON;
            break;
        case NSEventTypeOtherMouseDragged:
        case NSEventTypeOtherMouseDown:
        case NSEventTypeOtherMouseUp:
            modifiers |= EVENTFLAG_MIDDLE_MOUSE_BUTTON;
            break;
        default:
            break;
    }
    
    return modifiers;
}

+ (BOOL)isKeyPadEvent:(NSEvent*)event {
    if ([event modifierFlags] & NSEventModifierFlagNumericPad) {
        return true;
    }
    
    switch ([event keyCode]) {
        case 71:  // Clear
        case 81:  // =
        case 75:  // /
        case 67:  // *
        case 78:  // -
        case 69:  // +
        case 76:  // Enter
        case 65:  // .
        case 82:  // 0
        case 83:  // 1
        case 84:  // 2
        case 85:  // 3
        case 86:  // 4
        case 87:  // 5
        case 88:  // 6
        case 89:  // 7
        case 91:  // 8
        case 92:  // 9
            return true;
    }
    
    return false;
}

- (void)doMessageLoopWork {
    webview_cef::doMessageLoopWork();
}

- (id) init {
    self = [super init];
    if (self) {
        _plugin = std::make_shared<webview_cef::WebviewPlugin>();
        if(isCefProcessInit == NO){
            webview_cef::initCEFProcesses();
            isCefProcessInit = YES;
        }
        _plugin->setInvokeMethodFunc([=](std::string method, WValue* arguments){
            NSObject *arg = [CefWrapper encode_wvalue_to_flvalue:arguments];
            [self.channel invokeMethod:[NSString stringWithUTF8String:method.c_str()] arguments:arg];
        });

        _plugin->setCreateTextureFunc([=]() {
            std::shared_ptr<WebviewTextureRenderer> renderer = std::make_shared<WebviewTextureRenderer>(self.textureRegistry);
            return std::dynamic_pointer_cast<webview_cef::WebviewTexture>(renderer);
        });
    }
    return self;
}

- (void) handleMethodCallWrapper: (FlutterMethodCall*)call result:(FlutterResult)result{
    std::string name = std::string([call.method cStringUsingEncoding:NSUTF8StringEncoding]);
    WValue *encodeArgs = [CefWrapper encode_flvalue_to_wvalue:call.arguments];
    self->_plugin->HandleMethodCall(name, encodeArgs, [=](int ret, WValue* args){
        if(ret != 0){
            result([CefWrapper encode_wvalue_to_flvalue:args]);
        }
        else{
            result(nil);
        }
    });
    if(isCefMessageLoop == NO){
        _timer = [NSTimer timerWithTimeInterval:0.016f target:self selector:@selector(doMessageLoopWork) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer: _timer forMode:NSRunLoopCommonModes];
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            if([CefWrapper processKeyboardEvent:event]){
                return nil;
            }
            return event;
        }];
            
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            if([CefWrapper processKeyboardEvent:event]){
                return nil;
            }
            return event;
        }];
        isCefMessageLoop = YES;
   }
    webview_value_unref(encodeArgs);
}
@end
