//
//  NSInvocation+RJEventTracking.h
//  RJEventTracking
//
//  Created by Ryan Jin on 2019/10/7.
//

#import <Foundation/Foundation.h>

@interface NSInvocation (RJEventTracking)

@property (nonatomic,   copy)           NSArray *arguments;
@property (nonatomic, strong, readonly) id returnValue_obj;

@end
