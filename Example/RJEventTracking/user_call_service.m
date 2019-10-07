//
//  user_call_service.m
//  RJEventTracking_Example
//
//  Created by Ryan Jin on 2019/10/7.
//  Copyright © 2019 RylanJIN. All rights reserved.
//

#import "user_call_service.h"

@implementation user_call_service

- (NSString *)trackingMethod:(NSString *)method instance:(id)instance arguments:(NSArray *)arguments {
    if (![method isEqualToString:@"callService:"]) {
        return nil;
    }
    NSInteger orderType = [[instance property:@"orderType"] integerValue];
    if (orderType == 0) {
        return @"book1_call_service";
    } else {
        return @"book2_call_service";
    }
}

@end
