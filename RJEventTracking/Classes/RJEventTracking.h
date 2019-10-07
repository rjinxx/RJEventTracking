//
//  RJEventTracking.h
//  RJEventTracking
//
//  Created by Ryan Jin on 2019/10/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol RJEventTracking <NSObject>

- (nullable NSString *)trackingMethod:(NSString *)method instance:(id)instance arguments:(NSArray *)arguments;

@end

@interface NSObject (RJEventTracking)

- (id)property:(NSString *)property;
- (id)performSelector:(NSString *)selector arguments:(nullable NSArray *)arguments;

- (id)extraProperty:(NSString *)property;
- (void)addExtraProperty:(NSString *)property defaultValue:(id)value;

@end

@interface RJEventTracking : NSObject

+ (void)loadConfiguration:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
