//
//  RJEventTracking.m
//  RJEventTracking
//
//  Created by Ryan Jin on 2019/10/7.
//

#import "RJEventTracking.h"
#import <Aspects/Aspects.h>
#import "NSInvocation+RJEventTracking.h"
#import <objc/runtime.h>

@implementation NSObject (RJEventTracking)

- (id)property:(NSString *)property {
    return [NSObject runMethodWithObject:self selector:property arguments:nil];
}

- (id)performSelector:(NSString *)selector arguments:(NSArray *)arguments {
    return [NSObject runMethodWithObject:self selector:selector arguments:arguments];
}

+ (id)performSelector:(NSString *)selector arguments:(NSArray *)arguments {
    return [NSObject runMethodWithClass:(id)self selector:selector arguments:arguments];
}

- (id)extraProperty:(NSString *)property {
    return objc_getAssociatedObject(self, NSSelectorFromString(property));
}

- (void)addExtraProperty:(NSString *)property defaultValue:(id)value {
    objc_setAssociatedObject(self, NSSelectorFromString(property), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Private

+ (id)runMethodWithObject:(id)object selector:(NSString *)selector arguments:(NSArray *)arguments {
    if (!object) return nil;
    
    if (arguments && [arguments isKindOfClass:NSArray.class] == NO) {
        arguments = @[arguments];
    }
    SEL sel = NSSelectorFromString(selector);
    
    NSMethodSignature *signature = [object methodSignatureForSelector:sel];
    if (!signature) {
        return nil;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector      = sel;
    invocation.arguments     = arguments;
    [invocation invokeWithTarget:object];
    
    return invocation.returnValue_obj;
}

+ (id)runMethodWithClass:(Class)cla selector:(NSString *)selector arguments:(NSArray *)arguments {
    SEL sel = NSSelectorFromString(selector);
    if (arguments && ![arguments isKindOfClass:NSArray.class]) {
        arguments = @[arguments];
    }
    
    if ([cla instancesRespondToSelector:sel]) { // instance method
        id instance                  = [[cla alloc] init];
        NSMethodSignature *signature = [instance methodSignatureForSelector:sel];
        NSInvocation *invocation     = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector          = sel;
        invocation.arguments         = arguments;
        [invocation invokeWithTarget:instance];
        
        return invocation.returnValue_obj;
    } else if ([cla respondsToSelector:sel]) { // class method
        NSMethodSignature *signature = [cla methodSignatureForSelector:sel];
        NSInvocation *invocation     = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector          = sel;
        invocation.arguments         = arguments;
        [invocation invokeWithTarget:cla];
        
        return invocation.returnValue_obj;
    }
    
    return nil;
}

@end

@implementation RJEventTracking

+ (void)loadConfiguration:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return;
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    NSArray *ts        = dict[@"tracking"];
    [ts enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        Class class              = NSClassFromString(obj[@"class"]);
        NSDictionary *ed         = obj[@"event"];
        NSMutableDictionary *td  = [NSMutableDictionary dictionaryWithCapacity:0];
        [ed enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSMutableArray *tArr = [NSMutableArray arrayWithCapacity:0];
            [tArr addObjectsFromArray:[obj isKindOfClass:[NSArray class]] ? obj : @[obj]];
            [tArr enumerateObjectsUsingBlock:^(NSString *m, NSUInteger idx, BOOL *stop) {
                if ([td.allKeys containsObject:m]) {
                    NSMutableArray *ms         = [td[m] mutableCopy];
                    if (![ms containsObject:key]) [ms addObject:key];
                    td[m] = ms;
                } else {
                    td[m] = @[key];
                }
            }];
        }];
        [td enumerateKeysAndObjectsUsingBlock:^(NSString *kmethod, NSArray <NSString *> *tArr, BOOL *stop) {
            SEL sel        = NSSelectorFromString(kmethod);
            NSError *error = nil;
            [self checkValidWithClass:obj[@"class"] method:kmethod];
            [class aspect_hookSelector:sel withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
                [tArr enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL *stop) {
                    NSString *ename       = name;
                    id<RJEventTracking> t = [NSClassFromString(name) new];
                    if (t && [t respondsToSelector:@selector(trackingMethod:instance:arguments:)]) {
                        ename = [t trackingMethod:kmethod instance:info.instance
                                        arguments:info.arguments];
                    }
                    if ([ename length]) {
                        // report event tracking to server
                        NSLog(@"<RJEventTracking> - %@", ename);
                    }
                }];
            } error:&error];
            [self checkHookStatusWithClass:obj[@"class"] method:kmethod error:error];
        }];
    }];
}

#pragma mark - Utility

+ (void)checkValidWithClass:(NSString *)class method:(NSString *)method {
    SEL sel       = NSSelectorFromString(method);
    Class c       = NSClassFromString(class);
    BOOL respond  = [c respondsToSelector:sel] || [c instancesRespondToSelector:sel];
    NSString *err = [NSString stringWithFormat:@"<RJEventTracking> - no specified method: %@ found on class: %@, please check", method, class];
    
    NSAssert(respond, err);
}

+ (void)checkHookStatusWithClass:(NSString *)class method:(NSString *)method error:(NSError *)error {
    if (!error) {
        return;
    }
    NSString *estr = [NSString stringWithFormat:@"<RJEventTracking> - hook method: %@ on class: %@ failed, %@",
                      method, class, error.localizedDescription];
    NSAssert(!error, estr);
}

@end
