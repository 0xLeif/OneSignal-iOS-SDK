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

#import "OSTriggerController.h"
#import "OSInAppMessagingDefines.h"
#import "OneSignalHelper.h"

@interface OSTriggerController ()
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSString *, id> *triggers;
@property (strong, nonatomic, nonnull) NSUserDefaults *defaults;
@property (strong, nonatomic, nonnull) OSDynamicTriggerController *dynamicTriggerController;
@end

@implementation OSTriggerController

- (instancetype _Nonnull)init {
    if (self = [super init]) {
        self.triggers = ([[self triggersFromUserDefaults] mutableCopy] ?: [NSMutableDictionary<NSString *, id> new]);
        self.defaults = [NSUserDefaults standardUserDefaults];
        self.dynamicTriggerController = [OSDynamicTriggerController new];
        self.dynamicTriggerController.delegate = self;
    }
    
    return self;
}

#pragma mark Public Methods
- (void)addTriggers:(NSDictionary<NSString *, id> *)triggers {
    @synchronized (self.triggers) {
        [self.triggers addEntriesFromDictionary:triggers];
        
        [self didUpdateTriggers];
    }
}

- (void)removeTriggersForKeys:(NSArray<NSString *> *)keys {
    @synchronized (self.triggers) {
        for (NSString *key in keys)
            [self.triggers removeObjectForKey:key];
        
        [self didUpdateTriggers];
    }
}

- (NSDictionary<NSString *, id> *)getTriggers {
    @synchronized (self.triggers) {
        return self.triggers;
    }
}

- (id)getTriggerValueForKey:(NSString *)key {
    @synchronized (self.triggers) {
        return self.triggers[key];
    }
}

#pragma mark Private Methods

/**
    Triggers on a message are structured as a 2D array, where the outer array represents OR conditions
    and the inner array represents AND conditions.
 
    Because of this structure, we use a nested for-loop. In the inner loop, it continues to evaluate. If
    at any point it determines a trigger condition is FALSE, it breaks and the outer loop continues to
    the next OR statement.
 
    But if the inner loop never hits a condition that is FALSE, it continues looping until it hits the
    last condition. If the last condition is also true, it returns YES for the entire method.
 
    Supports both String and Numeric value types & comparisons
*/
- (BOOL)messageMatchesTriggers:(OSInAppMessage *)message {
    if (message.triggers.count == 0)
        return true;
    
    for (NSArray <OSTrigger *> *conditions in message.triggers) {
        
        //dynamic triggers should be handled after looping through all other triggers
        NSMutableArray<OSTrigger *> *dynamicTriggers = [NSMutableArray new];
        
        var foundFalseTrigger = false;
        
        for (int i = 0; i < conditions.count; i++) {
            let trigger = conditions[i];
            
            if (OS_IS_DYNAMIC_TRIGGER(trigger.property))
                [dynamicTriggers addObject:trigger];
            else if (![self evaluateTrigger:trigger forMessage:message]) {
                foundFalseTrigger = true;
                break;
            }
        }
        
        // if we found a trigger that evaluates to false, loop to the next AND block
        if (foundFalseTrigger)
            continue;
        else if (dynamicTriggers.count == 0) {
            // no trigger was false and there are no triggers left to evaluate, so the
            // AND block is true and we should return true.
            return true;
        }
        
        // if we reach this point, all normal (non-time-based) triggers evaluated to true
        // now we can start setting up timers if needed.
        for (int i = 0; i < dynamicTriggers.count; i++) {
            let trigger = dynamicTriggers[i];
            
            // even if the trigger evaluates as "false" now, it may become true in the future
            // (for exmaple if it's a session-duration trigger that launches a timer)
            if (![self.dynamicTriggerController dynamicTriggerShouldFire:trigger withMessageId:message.messageId])
                break;
            else if (i == dynamicTriggers.count - 1)
                return true;
        }
    }
    
    return false;
}

- (BOOL)evaluateTrigger:(OSTrigger *)trigger forMessage:(OSInAppMessage *)message {
    if (!self.triggers[trigger.property] && ![trigger.property isEqualToString:OS_VIEWED_MESSAGE]) {
        // the value doesn't exist
        if (trigger.operatorType == OSTriggerOperatorTypeNotExists ||
            (trigger.operatorType == OSTriggerOperatorTypeNotEqualTo && trigger.value != nil)) {
            // the condition for this trigger is true since the value doesn't exist
            // either loop to the next condition, or return true if we are the last condition
            return true;
        } else {
            return false;
        }
    } else if (trigger.operatorType == OSTriggerOperatorTypeExists) {
        return true;
    } else if (trigger.operatorType == OSTriggerOperatorTypeNotExists) {
        return false;
    }
    
    //if we reach this point, the trigger has been set locally
    id realValue = self.triggers[trigger.property];
    
    // The logic for making sure messages can only be shown X times
    // is the same as triggers, except the value (view_count) comes from
    // a different source
    if ([OS_VIEWED_MESSAGE isEqualToString:trigger.property])
        realValue = @([self viewCountForMessageId:message.messageId]);
    
    if (trigger.operatorType == OSTriggerOperatorTypeContains) {
        if (![self array:realValue containsValue:trigger.value]) {
            return false;
        }
    } else if (![trigger.value isKindOfClass:[realValue class]] ||
               ([trigger.value isKindOfClass:[NSNumber class]] && ![self trigger:trigger matchesNumericValue:realValue]) ||
               ([trigger.value isKindOfClass:[NSString class]] && ![self trigger:trigger matchesStringValue:realValue])) {
        return false;
    }
    
    return true;
}

- (BOOL)triggerValue:(id)triggerValue isEqualToValue:(id)value {
    return ([triggerValue isKindOfClass:[value class]] &&
     (([triggerValue isKindOfClass:[NSNumber class]] && [triggerValue isEqualToNumber:value]) ||
      ([triggerValue isKindOfClass:[NSString class]] && [triggerValue isEqualToString:value])));
}

- (BOOL)array:(NSArray *)array containsValue:(id)value {
    if (!array) return false;
    
    for (id element in array)
        if ([self triggerValue:value isEqualToValue:element])
            return true;
    
    return false;
}

- (BOOL)trigger:(OSTrigger *)trigger matchesStringValue:(NSString *)realValue {
    switch (trigger.operatorType) {
        case OSTriggerOperatorTypeEqualTo:
            return [realValue isEqualToString:trigger.value];
        case OSTriggerOperatorTypeNotEqualTo:
            return [realValue isEqualToString:trigger.value];
        default:
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Attempted to use an invalid comparison operator (%@) on a string type", OS_OPERATOR_TO_STRING(trigger.operatorType)]];
    }
    
    return false;
}

- (BOOL)trigger:(OSTrigger *)trigger matchesNumericValue:(id)realValue {
    switch (trigger.operatorType) {
        case OSTriggerOperatorTypeGreaterThan:
            return [realValue doubleValue] > [trigger.value doubleValue];
        case OSTriggerOperatorTypeEqualTo:
            return [realValue isEqualToNumber:trigger.value];
        case OSTriggerOperatorTypeNotEqualTo:
            return ![realValue isEqualToNumber:trigger.value];
        case OSTriggerOperatorTypeLessThan:
            return [realValue doubleValue] < [trigger.value doubleValue];
        case OSTriggerOperatorTypeLessThanOrEqualTo:
            return [realValue doubleValue] <= [trigger.value doubleValue];
        case OSTriggerOperatorTypeGreaterThanOrEqualTo:
            return [realValue doubleValue] >= [trigger.value doubleValue];
        case OSTriggerOperatorTypeExists:
        case OSTriggerOperatorTypeNotExists:
        case OSTriggerOperatorTypeContains:
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Attempted to compare/check equality for a non-comparative operator (%@)", OS_OPERATOR_TO_STRING(trigger.operatorType)]];
    }
    
    return false;
}

- (void)displayedMessage:(OSInAppMessage *)message {
    var messageViewCount = 1;
    
    let key = OS_VIEWED_MESSAGE_TRIGGER(message.messageId);
    
    let previousCount = (NSNumber *)[self.defaults objectForKey:key];
    
    if ([previousCount isKindOfClass:[NSNumber class]])
        messageViewCount += [previousCount intValue];
    
    [self.defaults setObject:@(messageViewCount) forKey:key];
    [self.defaults synchronize];
}

- (int)viewCountForMessageId:(NSString *)messageId {
    let key = OS_VIEWED_MESSAGE_TRIGGER(messageId);
    
    let count = (NSNumber *)[self.defaults objectForKey:key];
    
    if (count)
        return [count intValue];
    else
        return 0;
}

- (NSDictionary<NSString *, id> * _Nullable)triggersFromUserDefaults {
    return [self.defaults dictionaryForKey:OS_TRIGGERS_KEY];
}

- (void)didUpdateTriggers {
    [self.defaults setObject:self.triggers forKey:OS_TRIGGERS_KEY];
    [self.defaults synchronize];
    
    [self.delegate triggerConditionChanged];
}

-(void)dynamicTriggerFired {
    [self.delegate triggerConditionChanged];
}

@end
