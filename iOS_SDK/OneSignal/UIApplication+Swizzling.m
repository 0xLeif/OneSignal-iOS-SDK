//
//  UIApplication+Swizzling.m
//  OneSignal
//
//  Created by Joseph Kalash on 7/22/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import <objc/runtime.h>

#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "NSObject+Extras.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static Class getClassWithProtocolInHierarchy(Class searchClass, Protocol* protocolToFind) {
    if (!class_conformsToProtocol(searchClass, protocolToFind)) {
        if ([searchClass superclass] == nil)
            return nil;
        Class foundClass = getClassWithProtocolInHierarchy([searchClass superclass], protocolToFind);
        if (foundClass)
            return foundClass;
        return searchClass;
    }
    return searchClass;
}

static void injectSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getInstanceMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    
    BOOL successful = class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    
    if (!successful) {
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        newMeth = class_getInstanceMethod(addToClass, newSel);
        Method orgMeth = class_getInstanceMethod(addToClass, makeLikeSel);
        method_exchangeImplementations(orgMeth, newMeth);
    }
}

@interface OneSignal ()
+ (void)didRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)token;
+ (void) remoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo;
+ (void) updateNotificationTypes:(int)notificationTypes;
+ (void)notificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive;
+ (void)processLocalActionBasedNotification:(UILocalNotification*) notification identifier:(NSString*)identifier;
+ (void)onFocus:(NSString*)state;
@end

@implementation UIApplication (Swizzling)
static Class delegateClass = nil;
+(Class)delegateClass {
    return delegateClass;
}

- (void)oneSignalDidRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    [OneSignal didRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:)])
        [self oneSignalDidRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
}

- (void)oneSignalDidFailRegisterForRemoteNotification:(UIApplication*)app error:(NSError*)err {
    [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat: @"Error registering for Apple push notifications. Error: %@", err]];
    
    if ([self respondsToSelector:@selector(oneSignalDidFailRegisterForRemoteNotification:error:)])
        [self oneSignalDidFailRegisterForRemoteNotification:app error:err];
}

- (void)oneSignalDidRegisterUserNotifications:(UIApplication*)application settings:(UIUserNotificationSettings*)notificationSettings {
    
    [OneSignal updateNotificationTypes:notificationSettings.types];
    if ([self respondsToSelector:@selector(oneSignalDidRegisterUserNotifications:settings:)])
        [self oneSignalDidRegisterUserNotifications:application settings:notificationSettings];
}


// Notification opened! iOS 6 ONLY!
- (void)oneSignalReceivedRemoteNotification:(UIApplication*)application userInfo:(NSDictionary*)userInfo {
    
    [OneSignal notificationOpened:userInfo isActive:[application applicationState] == UIApplicationStateActive];
    
    if ([self respondsToSelector:@selector(oneSignalReceivedRemoteNotification:userInfo:)])
        [self oneSignalReceivedRemoteNotification:application userInfo:userInfo];
}

// User Tap on Notification while app was in background - OR - Notification received (silent or not, foreground or background) on iOS 7+
- (void) oneSignalRemoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult)) completionHandler {
    
    //Call notificationAction if app is active -> not a silent notification but rather user tap on notification
    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        [OneSignal notificationOpened:userInfo isActive:YES];
    else [OneSignal remoteSilentNotification:application UserInfo:userInfo];
    
    if ([self respondsToSelector:@selector(oneSignalRemoteSilentNotification:UserInfo:fetchCompletionHandler:)]) {
        [self oneSignalRemoteSilentNotification:application UserInfo:userInfo fetchCompletionHandler:completionHandler];
        return;
    }
    
    if ([self respondsToSelector:@selector(oneSignalReceivedRemoteNotification:userInfo:)])
        [self oneSignalReceivedRemoteNotification:application userInfo:userInfo];
    
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void) oneSignalLocalNotificationOpened:(UIApplication*)application handleActionWithIdentifier:(NSString*)identifier forLocalNotification:(UILocalNotification*)notification completionHandler:(void(^)()) completionHandler {
    
    [OneSignal processLocalActionBasedNotification:notification identifier:identifier];
    
    if ([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:)])
        [self oneSignalLocalNotificationOpened:application handleActionWithIdentifier:identifier forLocalNotification:notification completionHandler:completionHandler];
    else completionHandler();
}

- (void)oneSignalLocalNotificationOpened:(UIApplication*)application notification:(UILocalNotification*)notification {
    
    [OneSignal processLocalActionBasedNotification:notification identifier:@"__DEFAULT__"];
    
    if([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:notification:)])
        [self oneSignalLocalNotificationOpened:application notification:notification];
}

- (void)oneSignalApplicationWillResignActive:(UIApplication*)application {
    
    [OneSignal onFocus:@"suspend"];
    
    if ([self respondsToSelector:@selector(oneSignalApplicationWillResignActive:)])
        [self oneSignalApplicationWillResignActive:application];
}

- (void)oneSignalApplicationDidBecomeActive:(UIApplication*)application {
    
    [OneSignal onFocus:@"resume"];
    
    if ([self respondsToSelector:@selector(oneSignalApplicationDidBecomeActive:)])
        [self oneSignalApplicationDidBecomeActive:application];
}

+ (void)load {
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(setDelegate:)), class_getInstanceMethod(self, @selector(setOneSignalDelegate:)));
}

- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate {
    
    if (delegateClass) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    delegateClass = getClassWithProtocolInHierarchy([delegate class], @protocol(UIApplicationDelegate));
    
    
    injectSelector(self.class, @selector(oneSignalRemoteSilentNotification:UserInfo:fetchCompletionHandler:),
                   delegateClass, @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:));
    
    injectSelector(self.class, @selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:),
                   delegateClass, @selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:));
    
    injectSelector(self.class, @selector(oneSignalDidFailRegisterForRemoteNotification:error:),
                   delegateClass, @selector(application:didFailToRegisterForRemoteNotificationsWithError:));
    
    injectSelector(self.class, @selector(oneSignalDidRegisterUserNotifications:settings:),
                   delegateClass, @selector(application:didRegisterUserNotificationSettings:));
    
    if (NSClassFromString(@"CoronaAppDelegate")) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    injectSelector(self.class, @selector(oneSignalReceivedRemoteNotification:userInfo:),
                   delegateClass, @selector(application:didReceiveRemoteNotification:));
    
    injectSelector(self.class, @selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:),
                   delegateClass, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    
    injectSelector(self.class, @selector(oneSignalLocalNotificationOpened:notification:),
                   delegateClass, @selector(application:didReceiveLocalNotification:));
    
    injectSelector(self.class, @selector(oneSignalApplicationWillResignActive:),
                   delegateClass, @selector(applicationWillResignActive:));
    
    injectSelector(self.class, @selector(oneSignalApplicationDidBecomeActive:),
                   delegateClass, @selector(applicationDidBecomeActive:));
    
    
    /* iOS 10.0: UNUserNotificationCenterDelegate instead of UIApplicationDelegate for methods handling opening app from notification
     Make sure AppDelegate does not conform to this protocol */
    if([[[UIDevice currentDevice] systemVersion] floatValue] >= 10.0)
        [OneSignalHelper conformsToUNProtocol];
    
    [self setOneSignalDelegate:delegate];
}

+(UIViewController*)topmostController:(UIViewController*)base {
    
    UINavigationController *baseNav = (UINavigationController*) base;
    UITabBarController *baseTab = (UITabBarController*) base;
    if (baseNav)
        return [UIApplication topmostController:baseNav.visibleViewController];
    
    else if (baseTab.selectedViewController)
        return [UIApplication topmostController:baseTab.selectedViewController];
    
    else if (base.presentedViewController)
        return [UIApplication topmostController:baseNav.presentedViewController];
    
    return base;
}

#pragma clang diagnostic pop
@end
