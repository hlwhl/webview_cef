//
//  CefWrapper.m
//  Pods-Runner
//
//  Created by Hao Linwei on 2022/8/18.
//

#import "CefWrapper.h"
#import <Foundation/Foundation.h>
#import "include/cef_base.h"
#import "../../common/webview_app.h"
#import "../../common/webview_handler.h"
#import "../../common/webview_cookieVisitor.h"
#import "../../common/webview_js_handler.h"
#import "../../common/webview_plugin.h"
#import "../../common/webview_value.h"
#include <thread>

NSObject<FlutterTextureRegistry>* tr;
CGFloat scaleFactor = 0.0;
CefMainArgs mainArgs;

static NSTimer* _timer;
static CVPixelBufferRef buf_cache;
static CVPixelBufferRef buf_temp;
dispatch_semaphore_t lock = dispatch_semaphore_create(1);

int64_t textureId;

FlutterMethodChannel* f_channel;

@implementation CefWrapper

+ (NSObject *)encode_wvalue_to_flvalue: (WValue*)args {
    WValueType type = webview_value_get_type(args);
    switch(type) {
        case Webview_Value_Type_Bool:
            return [NSNumber numberWithBool:webview_value_get_bool(args)];
        case Webview_Value_Type_Int:
            return [NSNumber numberWithInt:webview_value_get_int(args)];
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
            int len = webview_value_get_len(args);
            NSMutableArray* array = [NSMutableArray arrayWithCapacity:len];
            for(int i = 0; i < len; i++) {
                WValue* item = webview_value_get_list_value(args, i);
                [array addObject:[self encode_wvalue_to_flvalue:item]];
            }
            return array;
        }
        case Webview_Value_Type_Map: {
            int len = webview_value_get_len(args);
            NSMutableDictionary* dic = [NSMutableDictionary dictionaryWithCapacity:len];
            for(int i = 0; i < len; i++) {
                NSString *key = [self encode_wvalue_to_flvalue:webview_value_get_key(args, i)];
                WValue *value = webview_value_get_value(args, i);
                if (key != nil && value != nil) {
                    [dic setObject:[self encode_wvalue_to_flvalue:value] forKey:key];
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
            WValue* item = [self encode_flvalue_to_wvalue:array[i]];
            webview_value_append(wvalue, item);
            webview_value_unref(item);
        }
        return wvalue;
    } else if([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dic = (NSDictionary*)value;
        int len = (int)dic.count;
        WValue* wvalue = webview_value_new_map();
        for(int i = 0; i < len; i++) {
            WValue* key = [self encode_flvalue_to_wvalue:dic.allKeys[i]];
            WValue* item = [self encode_flvalue_to_wvalue:dic.allValues[i]];
            webview_value_set(wvalue, key, item);
            webview_value_unref(key);
            webview_value_unref(item);
        }
        return wvalue;
    } else {
        return nil;
    }
}

+ (void)processKeyboardEvent: (NSEvent*) event {
    CefKeyEvent keyEvent;
    
    keyEvent.native_key_code = [event keyCode];
    keyEvent.modifiers = [self getModifiersForEvent:event];
    
    //handle backspace
    if(keyEvent.native_key_code == 51) {
        keyEvent.character = 0;
        keyEvent.unmodified_character = 0;
    } else {
        NSString* s = [event characters];
        if([s length] == 0) {
            keyEvent.type = KEYEVENT_KEYDOWN;
        } else {
            keyEvent.type = KEYEVENT_CHAR;
        }
        if ([s length] > 0)
            keyEvent.character = [s characterAtIndex:0];
        
        s = [event charactersIgnoringModifiers];
        if ([s length] > 0)
            keyEvent.unmodified_character = [s characterAtIndex:0];
        
        if([event type] == NSKeyUp) {
            keyEvent.type = KEYEVENT_KEYUP;
        }
    }

    webview_cef::sendKeyEvent(keyEvent);
}

+ (int)getModifiersForEvent:(NSEvent*)event {
    int modifiers = 0;
    
    if ([event modifierFlags] & NSControlKeyMask)
        modifiers |= EVENTFLAG_CONTROL_DOWN;
    if ([event modifierFlags] & NSShiftKeyMask)
        modifiers |= EVENTFLAG_SHIFT_DOWN;
    if ([event modifierFlags] & NSAlternateKeyMask)
        modifiers |= EVENTFLAG_ALT_DOWN;
    if ([event modifierFlags] & NSCommandKeyMask)
        modifiers |= EVENTFLAG_COMMAND_DOWN;
    if ([event modifierFlags] & NSAlphaShiftKeyMask)
        modifiers |= EVENTFLAG_CAPS_LOCK_ON;
    
    if ([event type] == NSKeyUp || [event type] == NSKeyDown ||
        [event type] == NSFlagsChanged) {
        // Only perform this check for key events
        //    if ([self isKeyPadEvent:event])
        //      modifiers |= EVENTFLAG_IS_KEY_PAD;
    }
    
    // OS X does not have a modifier for NumLock, so I'm not entirely sure how to
    // set EVENTFLAG_NUM_LOCK_ON;
    //
    // There is no EVENTFLAG for the function key either.
    
    // Mouse buttons
    switch ([event type]) {
        case NSLeftMouseDragged:
        case NSLeftMouseDown:
        case NSLeftMouseUp:
            modifiers |= EVENTFLAG_LEFT_MOUSE_BUTTON;
            break;
        case NSRightMouseDragged:
        case NSRightMouseDown:
        case NSRightMouseUp:
            modifiers |= EVENTFLAG_RIGHT_MOUSE_BUTTON;
            break;
        case NSOtherMouseDragged:
        case NSOtherMouseDown:
        case NSOtherMouseUp:
            modifiers |= EVENTFLAG_MIDDLE_MOUSE_BUTTON;
            break;
        default:
            break;
    }
    
    return modifiers;
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    buf_temp = buf_cache;
    CVPixelBufferRetain(buf_temp);
    dispatch_semaphore_signal(lock);
    return buf_temp;
}

+ (void)setMethodChannel: (FlutterMethodChannel*)channel {
    f_channel = channel;
    auto invoke = [=](std::string method, WValue* arguments){
        NSObject *arg = [self encode_wvalue_to_flvalue:arguments];
        [f_channel invokeMethod:[NSString stringWithUTF8String:method.c_str()] arguments:arg];
    };
    webview_cef::setInvokeMethodFunc(invoke);
}

+ (void)doMessageLoopWork {
    webview_cef::doMessageLoopWork();
}

+ (void) handleMethodCallWrapper: (FlutterMethodCall*)call result:(FlutterResult)result{
    std::string name = std::string([call.method cStringUsingEncoding:NSUTF8StringEncoding]);
    if(name.compare("init") == 0){
        textureId = [tr registerTexture:[CefWrapper alloc]];
        auto callback = [](const void* buffer, int32_t width, int32_t height) {
            NSDictionary* dic = @{
                (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                (__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
                (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
                (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
            };
            
            static CVPixelBufferRef buf = NULL;
            CVPixelBufferCreate(kCFAllocatorDefault,  width,
                                height, kCVPixelFormatType_32BGRA,
                                (__bridge CFDictionaryRef)dic, &buf);
            
            //copy data
            CVPixelBufferLockBaseAddress(buf, 0);
            char *copyBaseAddress = (char *) CVPixelBufferGetBaseAddress(buf);
            
            //MUST align pixel to pixelBuffer. Otherwise cause render issue. see https://www.codeprintr.com/thread/6563066.html about 16 bytes align
            size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buf, 0);
            char* src = (char*) buffer;
            int actureRowSize = width * 4;
            for(int line = 0; line < height; line++) {
                memcpy(copyBaseAddress, src, actureRowSize);
                src += actureRowSize;
                copyBaseAddress += bytesPerRow;
            }
            CVPixelBufferUnlockBaseAddress(buf, 0);
            
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            if(buf_cache) {
                CVPixelBufferRelease(buf_cache);
            }
            buf_cache = buf;
            dispatch_semaphore_signal(lock);
            [tr textureFrameAvailable:textureId];
        };
        webview_cef::initCEFProcesses();
        webview_cef::setPaintCallBack(callback);

        _timer = [NSTimer timerWithTimeInterval:0.016f target:self selector:@selector(doMessageLoopWork) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer: _timer forMode:NSRunLoopCommonModes];
        
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            [self processKeyboardEvent:event];
            return event;
        }];
        
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            [self processKeyboardEvent:event];
            return event;
        }];
        result([NSNumber numberWithLong:textureId]);
    }else{
        WValue *encodeArgs = [self encode_flvalue_to_wvalue:call.arguments];
        webview_cef::HandleMethodCall(name, encodeArgs, [=](int ret, WValue* args){
            if(ret != 0){
                result([self encode_wvalue_to_flvalue:args]);
            }
            else{
                result(nil);
            }
        });
        webview_value_unref(encodeArgs);
    }
}
@end
