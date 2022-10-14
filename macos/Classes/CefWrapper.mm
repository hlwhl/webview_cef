//
//  CefWrapper.m
//  Pods-Runner
//
//  Created by Hao Linwei on 2022/8/18.
//

#import "CefWrapper.h"
#import <Foundation/Foundation.h>
#import "include/wrapper/cef_library_loader.h"
#import "include/cef_app.h"
#import "../../common/webview_app.h"
#import "../../common/webview_handler.h"

#include <thread>

CefRefPtr<WebviewHandler> handler(new WebviewHandler());
CefRefPtr<WebviewApp> app(new WebviewApp(handler));
CefMainArgs mainArgs;

NSObject<FlutterTextureRegistry>* tr;
CGFloat scaleFactor = 0.0;

static NSTimer* _timer;
static CVPixelBufferRef buf_cache;
static CVPixelBufferRef buf_temp;
dispatch_semaphore_t lock = dispatch_semaphore_create(1);

int64_t textureId;

@implementation CefWrapper

+ (void)init {
    CefScopedLibraryLoader loader;
    
    if(!loader.LoadInMain()) {
        printf("load cef err");
    }
    
    CefMainArgs main_args;
    CefExecuteProcess(main_args, nullptr, nullptr);
}

+ (void)doMessageLoopWork {
    CefDoMessageLoopWork();
}

+ (void)startCef {
    textureId = [tr registerTexture:[CefWrapper alloc]];
    handler.get()->onPaintCallback = [](const void* buffer, int32_t width, int32_t height) {
        NSDictionary* dic = @{
            (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
            (__bridge NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
            (__bridge NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
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
    CefSettings settings;
    settings.windowless_rendering_enabled = true;
    settings.external_message_pump = true;
    CefString(&settings.browser_subprocess_path) = "/Library/Chaches";
    
    CefInitialize(mainArgs, settings, app.get(), nullptr);
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
    
    handler.get()->sendKeyEvent(keyEvent);
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

+(void)sendScrollEvent:(int)x y:(int)y deltaX:(int)deltaX deltaY:(int)deltaY {
    handler.get()->sendScrollEvent(x, y, deltaX, deltaY);
}

+ (void)cursorClickUp:(int)x y:(int)y {
    handler.get()->cursorClick(x, y, true);
}

+ (void)cursorClickDown:(int)x y:(int)y {
    handler.get()->cursorClick(x, y, false);
}

+ (void)cursorMove:(int)x y:(int)y dragging:(bool)dragging {
    handler.get()->cursorMove(x, y, dragging);
}

+ (void)sizeChanged:(float)dpi width:(int)width height:(int)height {
    handler.get()->changeSize(dpi, width, height);
}

+ (void)loadUrl:(NSString*)url {
    handler.get()->loadUrl(std::string([url cStringUsingEncoding:NSUTF8StringEncoding]));
}

+ (void)goForward {
    handler.get()->goForward();
}

+ (void)goBack {
    handler.get()->goBack();
}

+ (void)reload {
    handler.get()->reload();
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer {
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    buf_temp = buf_cache;
    CVPixelBufferRetain(buf_temp);
    dispatch_semaphore_signal(lock);
    return buf_temp;
}

@end
