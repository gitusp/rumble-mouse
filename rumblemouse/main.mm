//
//  main.m
//  rumblemouse
//
//  Created by usp on 7/23/16.
//  Copyright © 2016 usp. All rights reserved.
//

#import <mach/mach_time.h>
#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/CVDisplayLink.h>
#include <Carbon/Carbon.h>

// 押下中の方向キーを記憶する。
NSSet *currentDirections = [NSSet set];

long dv = 127;

// Current D-values.
long clx = dv;
long cly = dv;
long crx = dv;
long cry = dv;

// Display link.
CVDisplayLinkRef ref;

// HID Manager
IOHIDManagerRef manager;

// Previous absolute time.
uint64_t pt;

// Parameter for delta.
uint64_t lm = 320000000;
uint64_t rm = 120000000;

// Flags
bool isLinking = false;
bool isDash = false;
bool isDragging = false;

bool isNeutral(long v) {
    return dv - 10 < v && v < dv + 10;
}

CGPoint mouseLoc() {
    CGPoint mouseLoc = [NSEvent mouseLocation];
    return CGPointMake(mouseLoc.x, [[NSScreen mainScreen] frame].size.height - mouseLoc.y);
}

void tapEvents(NSArray *events) {
    for (NSValue *event in events) {
        CGEventRef eventRef = (CGEventRef)[event pointerValue];
        CGEventPost(kCGHIDEventTap, eventRef);
        CFRelease(eventRef);
    }
}

CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now, const CVTimeStamp *outputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *context) {
    if (pt != 0) {
        // Get delta.
        uint64_t ct = mach_absolute_time();
        uint64_t delta = ct - pt;
        
        // Create events.
        NSMutableArray *events = [NSMutableArray array];
        
        if (!isNeutral(clx) || !isNeutral(cly)) {
            CGPoint c = mouseLoc();
            CGSize s = [[NSScreen mainScreen] frame].size;
            float p = ((float)delta / (float)lm) * (isDash ? 2 : 1);
            int x = fmin(fmax(c.x + (clx - dv) * p, 0), s.width);
            int y = fmin(fmax(c.y + (cly - dv) * p, 0), s.height);
            CGEventRef ref = CGEventCreateMouseEvent(NULL, isDragging ? kCGEventLeftMouseDragged : kCGEventMouseMoved, CGPointMake(x, y), kCGMouseButtonLeft);
            [events addObject:[NSValue valueWithPointer:ref]];
        }
        
        if (!isNeutral(crx) || !isNeutral(cry)) {
            float p = ((float)delta / (float)rm) * (isDash ? 2 : 1);
            int x = (crx - dv) * p;
            int y = (cry - dv) * p;
            CGEventRef ref = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, -y, x);
            [events addObject:[NSValue valueWithPointer:ref]];
        }

        // Fire!
        tapEvents(events);
        
        pt = ct;
    } else {
        pt = mach_absolute_time();
    }
    
    return kCVReturnSuccess;
}

void manageDisplayLink() {
    if (isLinking && isNeutral(clx) && isNeutral(cly) && isNeutral(crx) && isNeutral(cry)) {
        CVDisplayLinkStop(ref);
        isLinking = false;
    } else if (!isLinking) {
        CVDisplayLinkStart(ref);
        isLinking = true;
        pt = 0;
    }
}

/** 値に応じたキーコードを返す **/
NSSet* keyCodesForDirection(long value) {
    switch (value) {
        case 0:
            return [NSSet setWithObjects:@(kVK_UpArrow), nil];
        case 1:
            return [NSSet setWithObjects:@(kVK_UpArrow), @(kVK_RightArrow), nil];
        case 2:
            return [NSSet setWithObjects:@(kVK_RightArrow), nil];
        case 3:
            return [NSSet setWithObjects:@(kVK_RightArrow), @(kVK_DownArrow), nil];
        case 4:
            return [NSSet setWithObjects:@(kVK_DownArrow), nil];
        case 5:
            return [NSSet setWithObjects:@(kVK_DownArrow), @(kVK_LeftArrow), nil];
        case 6:
            return [NSSet setWithObjects:@(kVK_LeftArrow), nil];
        case 7:
            return [NSSet setWithObjects:@(kVK_LeftArrow), @(kVK_UpArrow), nil];
        default:
            return [NSSet set];
    }
}

void handleInput(void *context, IOReturn result, void *sender, IOHIDValueRef valueRef) {
    if (result == kIOReturnSuccess) {
        // イベントの情報を取得する。
        IOHIDElementRef elementRef = IOHIDValueGetElement(valueRef);
        uint32_t usage = IOHIDElementGetUsage(elementRef);
        long value = IOHIDValueGetIntegerValue(valueRef);

        // 対応するイベントを設定する。
        NSMutableArray *events = [NSMutableArray array];
        
        if (usage == 2) {
            // Assign the usage to dash button.
            isDash = value != 0;
        }

        if (usage == 3) {
            // Assign the usage to click.
            CGEventRef eventRef = CGEventCreateMouseEvent(NULL, value == 0 ?  kCGEventLeftMouseUp : kCGEventLeftMouseDown, mouseLoc(), kCGMouseButtonLeft);
            CGEventSetFlags(eventRef, CGEventFlags());
            [events addObject:[NSValue valueWithPointer:eventRef]];
            isDragging = value != 0;
        }

        if (usage == 4) {
            // Assign the usage to command-click.
            CGEventRef eventRef = CGEventCreateMouseEvent(NULL, value == 0 ?  kCGEventLeftMouseUp : kCGEventLeftMouseDown, mouseLoc(), kCGMouseButtonLeft);
            CGEventSetFlags(eventRef, kCGEventFlagMaskCommand);
            [events addObject:[NSValue valueWithPointer:eventRef]];
            isDragging = value != 0;
        }

        if (usage == 10) {
            // Assign the usage to re-tab.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_T, value != 0);
            CGEventSetFlags(eventRef, CGEventFlags(kCGEventFlagMaskCommand | kCGEventFlagMaskShift));
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }
        
        if (usage == 5) {
            // Assign the usage to history back.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_LeftArrow, value != 0);
            CGEventSetFlags(eventRef, kCGEventFlagMaskCommand);
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 6) {
            // Assign the usage to history forward.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_RightArrow, value != 0);
            CGEventSetFlags(eventRef, kCGEventFlagMaskCommand);
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 7) {
            // Assign the usage to prev tab.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_LeftBracket, value != 0);
            CGEventSetFlags(eventRef, CGEventFlags(kCGEventFlagMaskCommand | kCGEventFlagMaskShift));
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 8) {
            // Assign the usage to prev tab.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_RightBracket, value != 0);
            CGEventSetFlags(eventRef, CGEventFlags(kCGEventFlagMaskCommand | kCGEventFlagMaskShift));
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 9) {
            // Assign the usage to close tab.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_W, value != 0);
            CGEventSetFlags(eventRef, kCGEventFlagMaskCommand);
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 1) {
            // Assign the usage to reload.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_R, value != 0);
            CGEventSetFlags(eventRef, kCGEventFlagMaskCommand);
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        // Assign stick to mouse move or wheel.

        if (usage == kHIDUsage_GD_X) {
            clx = value;
            manageDisplayLink();
        }

        if (usage == kHIDUsage_GD_Y) {
            cly = value;
            manageDisplayLink();
        }

        if (usage == kHIDUsage_GD_Z) {
            crx = value;
            manageDisplayLink();
        }
        
        if (usage == kHIDUsage_GD_Rz) {
            cry = value;
            manageDisplayLink();
        }

        if (usage == kHIDUsage_GD_Hatswitch) {
            // 方向キーが押されたか離された。
            NSSet *keyCodes = keyCodesForDirection(value);
            for (NSValue *keyCode in [currentDirections allObjects]) {
                if (![keyCodes containsObject:keyCode]) {
                    // 解放するべきキー。
                    int code = 0;
                    [keyCode getValue:&code];
                    CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, code, NO);
                    [events addObject:[NSValue valueWithPointer:eventRef]];
                }
            }
            for (NSValue *keyCode in [keyCodes allObjects]) {
                if (![currentDirections containsObject:keyCode]) {
                    // 新たに設定すべきキー。
                    int code = 0;
                    [keyCode getValue:&code];
                    CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, code, YES);
                    [events addObject:[NSValue valueWithPointer:eventRef]];
                }
            }
            // 押されている方向を記憶する。
            currentDirections = keyCodes;
        }
        
        // イベントを発火する。
        tapEvents(events);
    }
}

void cleanUp() {
    CFRelease(manager);
    CVDisplayLinkRelease(ref);
}

void SignalHandler(int sigraised) {
    cleanUp();
    fprintf(stderr, "Bye\n");
    exit(0);
}

int main(int argc, const char * argv[]) {
    signal(SIGINT, SignalHandler);
    
    // IOHIDManagerをデフォルトの設定で作成する。
    manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
    // マッチングするデバイスの条件を定義する。
    NSDictionary* criteria = @{
                               @kIOHIDDeviceUsagePageKey: @(kHIDPage_GenericDesktop),
                                @kIOHIDDeviceUsageKey: @(kHIDUsage_GD_Joystick),
                                @kIOHIDVendorIDKey: @(0x046d),
                                @kIOHIDProductIDKey: @(0xc218),
                                };
    // 上記の条件を設定する。
    IOHIDManagerSetDeviceMatching(manager, (__bridge CFDictionaryRef)criteria);
    // 作成したIOHIDManagerを現在のループに紐付ける。
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    // デバイスを作成したIOHIDManagerで扱うように設定する。
    // 第二引数にkIOHIDOptionsTypeSeizeDeviceを渡すことで、排他的に扱うように設定している。
    IOReturn ret = IOHIDManagerOpen(manager, kIOHIDOptionsTypeSeizeDevice);
    if (ret != kIOReturnSuccess) {
        fprintf(stderr, "Failed to open\n");
    } else {
        // 入力ハンドラを設定する。
        IOHIDManagerRegisterInputValueCallback(manager, &handleInput, NULL);
    }

    // Initialize display link.
    CVDisplayLinkCreateWithActiveCGDisplays(&ref);
    CVDisplayLinkSetOutputCallback(ref, displayLinkCallback, NULL);
    
    // ループに入り入力を待ち受ける。
    CFRunLoopRun();
    
    cleanUp();
}