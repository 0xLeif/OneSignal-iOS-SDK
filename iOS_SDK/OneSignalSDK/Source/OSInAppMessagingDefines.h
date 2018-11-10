/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#ifndef OSInAppMessagingDefines_h
#define OSInAppMessagingDefines_h

#import "OneSignal.h"

typedef NS_ENUM(NSUInteger, OSInAppMessageDisplayPosition) {
    OSInAppMessageDisplayPositionBottom,
    
    OSInAppMessageDisplayPositionTop,
    
    OSInAppMessageDisplayPositionCentered
};

#define MESSAGE_MARGIN 0.025f

#define BANNER_ASPECT_RATIO 2.3f
#define CENTERED_MODAL_ASPECT_RATIO 0.81f

#define MAX_DISMISSAL_ANIMATION_DURATION 0.3f

// Key for NSUserDefaults trigger storage
#define OS_TRIGGERS_KEY @"OS_IN_APP_MESSAGING_TRIGGERS"

// Dynamic trigger property types
#define OS_SESSION_DURATION_TRIGGER @"os_session_duration"
#define OS_TIME_TRIGGER @"os_time"
#define OS_SDK_VERSION_TRIGGER @"os_sdk_version"
#define OS_DEVICE_TYPE_TRIGGER @"os_device_type"
#define OS_DEVICE_TYPE_TABLET @"tablet"
#define OS_DEVICE_TYPE_PHONE @"phone"

#define OS_IS_DYNAMIC_TRIGGER(type) [@[@"os_session_duration", @"os_time", @"os_sdk_version"] containsObject:type]

// Maps OSInAppMessageDisplayType cases to the equivalent OSInAppMessageDisplayPosition cases
#define OS_DISPLAY_POSITION_FOR_TYPE(inAppMessageType) [[@[@(OSInAppMessageDisplayPositionTop), @(OSInAppMessageDisplayPositionCentered), @(OSInAppMessageDisplayPositionCentered), @(OSInAppMessageDisplayPositionBottom)] objectAtIndex: inAppMessageType] intValue]

// Checks if a string is a valid display type
#define OS_IS_VALID_DISPLAY_TYPE(stringType) [@[@"top_banner", @"centered_modal", @"full_screen", @"bottom_banner"] containsObject: stringType]

// Converts string like "top_banner" to its OSInAppMessageDisplayType enum case
#define OS_DISPLAY_TYPE_FOR_STRING(stringType) (OSInAppMessageDisplayType)[@[@"top_banner", @"centered_modal", @"full_screen", @"bottom_banner"] indexOfObject: stringType]


#endif /* OSInAppMessagingDefines_h */
