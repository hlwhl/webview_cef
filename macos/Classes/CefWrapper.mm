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

static NSTimer* _timer;

FlutterMethodChannel* f_channel;

typedef void(^RetainSelfBlock)(void);

@implementation CefWrapper
@synthesize textureId = _textureId;

{
    RetainSelfBlock _retainBlock;//通过这个block持有对象，造成循环引用，避免被释放
}

class WebviewTextureRenderer : public webview_cef::WebviewTexture {
public:
    WebviewTextureRenderer(){
        wrapped = [[CefWrapper alloc] init];
        textureId = [tr registerTexture:renderer];
        wrapped.textureId = textureId;
        // object->_retainBlock = ^{//循环引用
        //     [object class];
        // };
        // self = (__bridge void *)object;
    }

    virtual ~WebviewTextureRenderer() {
        [tr unregisterTexture:textureId];
        [wrapped release];  
        // [(__bridge id) self breakRetainCycly];
    }

    virtual void onFrame(const void* buffer, int width, int height) {
        [wrapped onFrame:buffer width:width height:height];
        // return [(__bridge id)self onFrame:buffer width:width height:height];
    }

private:
    CefWrapper *wrapped;
}

- (id) init {
    self = [super init];
    if (self) {
        _lock = dispatch_semaphore_create(1);
    }
    return self;
}

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
                WValue* item = webview_value_get_value(args, i);
                [array addObject:[self encode_wvalue_to_flvalue:item]];
            }
            return array;
        }
        case Webview_Value_Type_Map: {
            int64_t len = webview_value_get_len(args);
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

- (void)onFrame:(const void *)buffer width:(int64_t)width height:(int64_t)height{
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
            
    //MUST align pixel to _pixelBuffer. Otherwise cause render issue. see https://www.codeprintr.com/thread/6563066.html about 16 bytes align
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buf, 0);
    char* src = (char*) buffer;
    int actureRowSize = width * 4;
    for(int line = 0; line < height; line++) {
        memcpy(copyBaseAddress, src, actureRowSize);
        src += actureRowSize;
        copyBaseAddress += bytesPerRow;
    }
    CVPixelBufferUnlockBaseAddress(buf, 0);
            
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if(_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = buf;
    dispatch_semaphore_signal(_lock);
    [tr textureFrameAvailable:_textureId];
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    _pixelBufferTemp = _pixelBuffer;
    CVPixelBufferRetain(_pixelBufferTemp);
    dispatch_semaphore_signal(_lock);
    return _pixelBufferTemp;
}

+ (void)setMethodChannel: (FlutterMethodChannel*)channel {
    f_channel = channel;
    auto invoke = [=](std::string method, WValue* arguments){
        NSObject *arg = [self encode_wvalue_to_flvalue:arguments];
        [f_channel invokeMethod:[NSString stringWithUTF8String:method.c_str()] arguments:arg];
    };
    webview_cef::setInvokeMethodFunc(invoke);

	auto createTexture = [=]() {
		std::shared_ptr<WebviewTextureRenderer> renderer = std::make_shared<WebviewTextureRenderer>(texture_registrar);
		return std::dynamic_pointer_cast<webview_cef::WebviewTexture>(renderer);
	};
	webview_cef::setCreateTextureFunc(createTexture);

}

+ (void)doMessageLoopWork {
    webview_cef::doMessageLoopWork();
}

+ (NSObject*) handleMethodCallWrapper: (FlutterMethodCall*)call{
    std::string name = std::string([call.method cStringUsingEncoding:NSUTF8StringEncoding]);
    if(name.compare("init") == 0){
        webview_cef::initCEFProcesses();
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
    }else if(name.compare("dispose") == 0){
        [_timer invalidate];
    }
    WValue *encodeArgs = [self encode_flvalue_to_wvalue:call.arguments];
    WValue *responseArgs = nullptr;
    int ret = webview_cef::HandleMethodCall(name, encodeArgs, &responseArgs);
    webview_value_unref(encodeArgs);
    if(ret != 0){
        NSObject *result = [self encode_wvalue_to_flvalue:responseArgs];
        webview_value_unref(responseArgs);
        return result;
    }
    else{
        webview_value_unref(responseArgs);
    }
    return nil;
}
@end
