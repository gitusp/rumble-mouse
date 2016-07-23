//
//  main.m
//  rumblemouse
//
//  Created by usp on 7/23/16.
//  Copyright © 2016 usp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <AppKit/AppKit.h>
#include <Carbon/Carbon.h>

// 押下中の方向キーを記憶する。
NSSet *currentDirections = [NSSet set];

// Current D-values.
long clx = 127;
long cly = 127;
long crx = 127;
long cry = 127;

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

CGPoint mouseLoc() {
    CGPoint mouseLoc = [NSEvent mouseLocation];
    return CGPointMake(mouseLoc.x, [[NSScreen mainScreen] frame].size.height - mouseLoc.y);
}

void handleInput(void *context, IOReturn result, void *sender, IOHIDValueRef valueRef) {
    if (result == kIOReturnSuccess) {
        // イベントの情報を取得する。
        IOHIDElementRef elementRef = IOHIDValueGetElement(valueRef);
        uint32_t usage = IOHIDElementGetUsage(elementRef);
        long value = IOHIDValueGetIntegerValue(valueRef);

        // 対応するイベントを設定する。
        NSMutableArray *events = [NSMutableArray array];
        
        NSLog(@"usage: %d, value: %ld", usage, value);
        
        if (usage == 2) {
            // Assign the usage to close tab.
            CGEventRef eventRef = CGEventCreateKeyboardEvent(NULL, kVK_ANSI_W, value != 0);
            CGEventSetFlags(eventRef, kCGEventFlagMaskCommand);
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 3) {
            // Assign the usage to click.
            CGEventRef eventRef = CGEventCreateMouseEvent(NULL, value == 0 ?  kCGEventLeftMouseUp : kCGEventLeftMouseDown, mouseLoc(), kCGMouseButtonLeft);
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 4) {
            // Assign the usage to command-click.
            CGEventRef eventRef = CGEventCreateMouseEvent(NULL, value == 0 ?  kCGEventLeftMouseUp : kCGEventLeftMouseDown, mouseLoc(), kCGMouseButtonLeft);
            CGEventSetFlags(eventRef, kCGEventFlagMaskCommand);
            [events addObject:[NSValue valueWithPointer:eventRef]];
        }

        if (usage == 1) {
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

        // Assign stick to mouse move or wheel.

        if (usage == kHIDUsage_GD_X) {
            clx = value;
        }

        if (usage == kHIDUsage_GD_Y) {
            cly = value;
        }

        if (usage == kHIDUsage_GD_Z) {
            crx = value;
        }
        
        if (usage == kHIDUsage_GD_Rz) {
            cry = value;
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
        for (NSValue *event in events) {
            CGEventRef eventRef = (CGEventRef)[event pointerValue];
            CGEventPost(kCGHIDEventTap, eventRef);
            CFRelease(eventRef);
        }
    }
}

void SignalHandler(int sigraised) {
    fprintf(stderr, "Bye\n");
    exit(0);
}

int main(int argc, const char * argv[]) {
    signal(SIGINT, SignalHandler);
    
    // IOHIDManagerをデフォルトの設定で作成する。
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
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
    
    // ループに入り入力を待ち受ける。
    CFRunLoopRun();
}