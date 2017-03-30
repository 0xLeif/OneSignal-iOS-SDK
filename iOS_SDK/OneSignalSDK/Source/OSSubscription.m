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

#import "OSSubscription.h"


@implementation OSSubscriptionState

- (ObserableSubscriptionStateType*)observable {
    if (!_observable)
        _observable = [OSObservable new];
    return _observable;
}

- (instancetype)initAsToWithPermision:(BOOL)permission {
    _accpeted = permission;
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    _userId = [userDefaults stringForKey:@"GT_PLAYER_ID"];
    _pushToken = [userDefaults stringForKey:@"GT_DEVICE_TOKEN"];
    _userSubscriptionSetting = [userDefaults objectForKey:@"ONESIGNAL_SUBSCRIPTION"] == nil;
    
    return self;
}

- (BOOL)compareWithFrom:(OSSubscriptionState*)from {
    return self.userId != from.userId ||
    self.pushToken != from.pushToken ||
    self.userSubscriptionSetting != from.userSubscriptionSetting ||
    self.accpeted != from.accpeted;
}

- (instancetype)initAsFrom {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    _userId = [userDefaults stringForKey:@"GT_PLAYER_ID_LAST"];
    _pushToken = [userDefaults stringForKey:@"GT_DEVICE_TOKEN_LAST"];
    _userSubscriptionSetting = [userDefaults boolForKey:@"ONESIGNAL_SUBSCRIPTION_LAST"];
    _accpeted = [userDefaults boolForKey:@"ONESIGNAL_PERMISSION_ACCEPTED_LAST"];
    
    return self;
}

- (void)persistAsFrom {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:_userId forKey:@"GT_PLAYER_ID_LAST"];
    [userDefaults setObject:_pushToken forKey:@"GT_DEVICE_TOKEN_LAST"];
    [userDefaults setBool:_userSubscriptionSetting forKey:@"ONESIGNAL_SUBSCRIPTION_LAST"];
    [userDefaults setBool:_accpeted forKey:@"ONESIGNAL_PERMISSION_ACCEPTED_LAST"];
    
    [userDefaults synchronize];
}

- (instancetype)copyWithZone:(NSZone*)zone {
    OSSubscriptionState* copy = [[[self class] alloc] init];
    
    if (copy) {
        copy->_userId = [_userId copy];
        copy->_pushToken = [_pushToken copy];
        copy->_userSubscriptionSetting = _userSubscriptionSetting;
        copy->_accpeted = _accpeted;
    }
    
    return copy;
}


- (void)onChanged:(OSPermissionState*)state {
    [self setAccepted:state.accepted];
}

- (void)setUserId:(NSString*)userId {
    BOOL changed = ![[NSString stringWithString:userId] isEqualToString:_userId];
    _userId = userId;
    if (self.observable && changed)
        [self.observable notifyChange:self];
}

- (void)setPushToken:(NSString*)pushToken {
    BOOL changed = ![[NSString stringWithString:pushToken] isEqualToString:_pushToken];
    _pushToken = pushToken;
    if (self.observable && changed)
        [self.observable notifyChange:self];
}

- (void)setUserSubscriptionSetting:(BOOL)userSubscriptionSetting {
    BOOL changed = userSubscriptionSetting != _userSubscriptionSetting;
    _userSubscriptionSetting = userSubscriptionSetting;
    if (self.observable && changed)
        [self.observable notifyChange:self];
}

- (void)setAccepted:(BOOL)inAccpeted {
    BOOL lastSubscribed = self.subscribed;
    _accpeted = inAccpeted;
    if (lastSubscribed != self.subscribed)
        [self.observable notifyChange:self];
}

- (BOOL)subscribed {
    return _userId && _pushToken && _userSubscriptionSetting && _accpeted;
}

@end


@implementation OSSubscriptionChangedInternalObserver

- (void)onChanged:(OSSubscriptionState*)state {
    OSSubscriptionStateChanges* stateChanges = [OSSubscriptionStateChanges alloc];
    stateChanges.from = OneSignal.lastSubscriptionState;
    stateChanges.to = [state copy];
    
    [OneSignal.subscriptionStateChangesObserver notifyChange:stateChanges];
    
    OneSignal.lastSubscriptionState = [state copy];
    [OneSignal.lastSubscriptionState persistAsFrom];
}

@end

@implementation OSSubscriptionStateObserverWrapper {
    NSObject<OSSubscriptionObserver>* _observer;
}

- (instancetype)initWithOSSubscriptionObserver:(NSObject<OSSubscriptionObserver>*)observer {
    _observer = observer;
    return self;
}

- (void)onChanged:(OSSubscriptionStateChanges*)state {
    // Don't fire for pushToken that is autotmaticly retreived.
    if (state.to.pushToken && !state.from.pushToken && !state.to.userId)
        return;
    
    if (!state.to.userId)
        state.to->_pushToken = nil;
    
    if (!state.from.userId)
        state.from->_pushToken = nil;
    
    [_observer onOSSubscriptionChanged:state];
}

@end


@implementation OSSubscriptionStateChanges
@end
