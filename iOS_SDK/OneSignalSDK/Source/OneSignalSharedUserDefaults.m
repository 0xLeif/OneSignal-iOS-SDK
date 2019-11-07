/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
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

#import <Foundation/Foundation.h>
#import "OneSignalSharedUserDefaults.h"
#import "OneSignalExtensionBadgeHandler.h"

@implementation OneSignalSharedUserDefaults : NSObject

+ (NSUserDefaults*)getSharedUserDefault {
    return [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
}

+ (BOOL)keyExists:(NSString *)key {
    return [[OneSignalSharedUserDefaults getSharedUserDefault] objectForKey:key] != nil;
}

+ (void)saveString:(NSString *)value withKey:(NSString *)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    [userDefaults setObject:value forKey:key];
    [userDefaults synchronize];
}

+ (NSString *)getSavedString:(NSString *)key defaultValue:(NSString *)value {
    if ([OneSignalSharedUserDefaults keyExists:key])
        return [[OneSignalSharedUserDefaults getSharedUserDefault] objectForKey:key];
    
    return value;
}

+ (void)saveBool:(BOOL)boolean withKey:(NSString *)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    [userDefaults setBool:boolean forKey:key];
    [userDefaults synchronize];
}

+ (BOOL)getSavedBool:(NSString *)key defaultValue:(BOOL)value {
    if ([OneSignalSharedUserDefaults keyExists:key])
        return (BOOL) [[OneSignalSharedUserDefaults getSharedUserDefault] boolForKey:key];
    
    return value;
}

+ (void)saveInteger:(NSInteger)integer withKey:(NSString *)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    [userDefaults setObject:[NSString stringWithFormat:@"%li", (long)integer] forKey:key];
    [userDefaults synchronize];
}

+ (NSInteger)getSavedInteger:(NSString *)key defaultValue:(NSInteger)value {
    if ([OneSignalSharedUserDefaults keyExists:key]) {
        NSString *result = [self getSavedObject:key defaultValue:[NSString stringWithFormat:@"%li", (long)value]];
        return [result intValue];
    }
    return value;
}

+ (void)saveCodeableData:(id)data withKey:(NSString *)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:data] forKey:key];
    [userDefaults synchronize];
}

+ (id)getSavedCodeableData:(NSString *)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    return [NSKeyedUnarchiver unarchiveObjectWithData:[userDefaults objectForKey:key]];
}

+ (void)saveObject:(id)object withKey:(NSString *)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setObject:object forKey:key];
    [userDefaults synchronize];
}

+ (id)getSavedObject:(NSString *)key defaultValue:(id)value {
    if ([OneSignalSharedUserDefaults keyExists:key])
        return [[OneSignalSharedUserDefaults getSharedUserDefault] objectForKey:key];
    
    return value;
}

+ (NSString *)appGroupKey {
    return [OneSignalExtensionBadgeHandler appGroupName];
}

@end
