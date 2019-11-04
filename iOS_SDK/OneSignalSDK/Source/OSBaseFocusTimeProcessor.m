/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import "OSSessionResult.h"
#import "OSBaseFocusTimeProcessor.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"

const int MIN_ON_FOCUS_TIME_SEC = 60;

@implementation OSBaseFocusTimeProcessor
NSNumber* unsentActiveTime;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _onFocusCallEnabled = YES;
    }
    return self;
}

- (int)getMinSessionTime {
    return MIN_ON_FOCUS_TIME_SEC;
}
- (BOOL)isTimeCorrect:(NSTimeInterval)activeTime {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"OSBaseFocusTimeProcessor isTimeCorrect getMinSessionTime: %d activeTime: %f", [self getMinSessionTime], activeTime]];
    return activeTime > [self getMinSessionTime];
}

- (void)resetUnsentActiveTime {
    unsentActiveTime = nil;
}

- (void)setOnFocusCallEnabled:(BOOL)enabled {
    _onFocusCallEnabled = enabled;
}

- (void)saveUnsentActiveTime:(NSTimeInterval)time {
    [OneSignalUserDefaults saveObject:@(time) withKey:UNSENT_ACTIVE_TIME];
}

- (NSTimeInterval)getUnsentActiveTime {
    if (!unsentActiveTime)
        unsentActiveTime = [OneSignalUserDefaults getSavedObject:UNSENT_ACTIVE_TIME defaultValue:@0];
    
    return [unsentActiveTime doubleValue];
}

@end
