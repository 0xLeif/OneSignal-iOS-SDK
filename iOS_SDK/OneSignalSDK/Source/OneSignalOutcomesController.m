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

#import <Foundation/Foundation.h>
#import "OneSignalOutcomeController.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalNotificationData.h"

@implementation OneSignalOutcomesController

NSString * const WEIGHT = @"weight";
NSString * const TIMESTAMP = @"timestamp";

NSMutableSet *outcomesSent;
OneSignalSessionManager *outcomesSessionManager;

- (id)init {
    outcomesSent = [NSMutableSet set];
    return self;
}

- (void)sendOutcomeEventRequest:(OneSignalRequest * _Nonnull)request
                   successBlock:(OSResultSuccessBlock _Nullable)success
                   failureBlock:(OSFailureBlock _Nullable)failure  {
    
    [OneSignalClient.sharedClient executeRequest:request onSuccess:^(NSDictionary *result) {
        if (success != nil) {
            success(result);
        }
    } onFailure:^(NSError *error) {
        //TODO save on cache
        if (failure != nil) {
            failure(error);
        }
    }];
}

- (void)clearOutcomes {
    outcomesSent = [NSMutableSet set];
}

- (void)sendUniqueOutcomeEvent:(NSString * _Nonnull)name
                         appId:(NSString * _Nonnull)appId
                    deviceType:(NSNumber * _Nonnull)deviceType
                  successBlock:(OSResultSuccessBlock _Nullable)success
                  failureBlock:(OSFailureBlock _Nullable)failure {
    if ([outcomesSent containsObject:name]) {
        //Outcome already sent
        return;
    }
    [outcomesSent addObject:name];
    [self sendOutcomeEvent:name appId:appId deviceType:deviceType successBlock:success failureBlock:failure];
}

- (void)sendOutcomeEvent:(NSString * _Nonnull)name
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSResultSuccessBlock _Nullable)success
            failureBlock:(OSFailureBlock _Nullable)failure {
    
    [self sendOutcomeEvent:name value:nil appId:appId deviceType:deviceType successBlock:success failureBlock:failure];
}

- (void)sendOutcomeEvent:(NSString * _Nonnull)name
                   value:(NSNumber * _Nullable)weight
                   appId:(NSString * _Nonnull)appId
              deviceType:(NSNumber * _Nonnull)deviceType
            successBlock:(OSResultSuccessBlock _Nullable)success
            failureBlock:(OSFailureBlock _Nullable)failure {
    
    NSString *notificationId = [OneSignalNotificationData getLastNotificationId];
    NSDictionary *requestParams = nil;
    if (weight != nil) {
        requestParams = @{ WEIGHT : weight };
    }
    
    if (notificationId == nil || [notificationId length] == 0) {
        [self sendOutcomeEventRequest:[OSRequestSendOutcomesToServer unattributedWithOutcomeId:name appId:appId deviceType:deviceType requestParams:requestParams] successBlock:success failureBlock:failure];
        return;
    }
    
    switch ([OneSignalSessionManager session]) {
        case DIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending direct outcome"];
            [self sendOutcomeEventRequest:[OSRequestSendOutcomesToServer directWithOutcomeId:name appId:appId notificationId:notificationId deviceType:deviceType requestParams:requestParams] successBlock:success failureBlock:failure];
            break;
        case INDIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending indirect outcome"];
            [self sendOutcomeEventRequest:[OSRequestSendOutcomesToServer indirectWithOutcomeId:name appId:appId notificationId:notificationId deviceType:deviceType requestParams:requestParams] successBlock:success failureBlock:failure];
            break;
        case UNATTRIBUTED:
        case NONE:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending unattributed outcome"];
            [self sendOutcomeEventRequest:[OSRequestSendOutcomesToServer unattributedWithOutcomeId:name appId:appId deviceType:deviceType requestParams:requestParams] successBlock:success failureBlock:failure];
            break;
    }
}

@end
