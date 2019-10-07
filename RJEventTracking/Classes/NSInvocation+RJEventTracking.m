//
//  NSInvocation+RJEventTracking.m
//  RJEventTracking
//
//  Created by Ryan Jin on 2019/10/7.
//

#import "NSInvocation+RJEventTracking.h"
#import <objc/runtime.h>

@implementation NSInvocation (RJEventTracking)

- (id)returnValue_obj {
    NSMethodSignature *sig = self.methodSignature;
    NSInvocation *inv = self;
    NSUInteger length = [sig methodReturnLength];
    
    if (length == 0) return nil;
    
    char *type = (char *)[sig methodReturnType];
    while (*type == 'r' || // const
           *type == 'n' || // in
           *type == 'N' || // inout
           *type == 'o' || // out
           *type == 'O' || // bycopy
           *type == 'R' || // byref
           *type == 'V') { // oneway
        type++; // cutoff useless prefix
    }
    
#define return_with_number(_type_) \
do { \
_type_ ret; \
[inv getReturnValue:&ret]; \
return @(ret); \
} while (0)
    
    switch (*type) {
        case 'v': return nil; // void
        case 'B': return_with_number(bool);
        case 'c': return_with_number(char);
        case 'C': return_with_number(unsigned char);
        case 's': return_with_number(short);
        case 'S': return_with_number(unsigned short);
        case 'i': return_with_number(int);
        case 'I': return_with_number(unsigned int);
        case 'l': return_with_number(int);
        case 'L': return_with_number(unsigned int);
        case 'q': return_with_number(long long);
        case 'Q': return_with_number(unsigned long long);
        case 'f': return_with_number(float);
        case 'd': return_with_number(double);
        case 'D': { // long double
            long double ret;
            [inv getReturnValue:&ret];
            return [NSNumber numberWithDouble:ret];
        };
            
        case '@': { // id
            void *ret;
            [inv getReturnValue:&ret];
            return (__bridge id)(ret);
        };
            
        case '#': { // Class
            Class ret = nil;
            [inv getReturnValue:&ret];
            return ret;
        };
            
        default: { // struct / union / SEL / void* / unknown
            const char *objCType = [sig methodReturnType];
            char *buf = calloc(1, length);
            if (!buf) return nil;
            [inv getReturnValue:buf];
            NSValue *value = [NSValue valueWithBytes:buf objCType:objCType];
            free(buf);
            return value;
        };
    }
#undef return_with_number
}

- (void)rj_setArgument:(id)obj atIndex:(NSInteger)argumentIndex {
#define set_with_args_index(_index_, _type_, _sel_) \
do { \
_type_ arg; \
arg = [obj _sel_]; \
[self setArgument:&arg atIndex:_index_]; \
} while(0)
    
#define set_with_args_struct(_dic_, _struct_, _param_, _key_, _sel_) \
do { \
if (_dic_ && [_dic_ isKindOfClass:[NSDictionary class]]) { \
if ([_dic_.allKeys containsObject:_key_]) { \
_struct_._param_ = [_dic_[_key_] _sel_]; \
} \
} \
} while(0)
    NSMethodSignature *sig = self.methodSignature;
    NSUInteger count = [sig numberOfArguments];
    NSInteger index = argumentIndex + 2;
    
    if (index >= count) {
        return;
    }
    
    char *type = (char *)[sig getArgumentTypeAtIndex:index];
    while (*type == 'r' ||  // const
           *type == 'n' ||  // in
           *type == 'N' ||  // inout
           *type == 'o' ||  // out
           *type == 'O' ||  // bycopy
           *type == 'R' ||  // byref
           *type == 'V') {  // oneway
        type++;             // cutoff useless prefix
    }
    
    BOOL unsupportedType = NO;
    switch (*type) {
        case 'v':   // 1:void
        case 'B':   // 1:bool
        case 'c':   // 1: char / BOOL
        case 'C':   // 1: unsigned char
        case 's':   // 2: short
        case 'S':   // 2: unsigned short
        case 'i':   // 4: int / NSInteger(32bit)
        case 'I':   // 4: unsigned int / NSUInteger(32bit)
        case 'l':   // 4: long(32bit)
        case 'L':   // 4: unsigned long(32bit)
        { // 'char' and 'short' will be promoted to 'int'
            set_with_args_index(index, int, intValue);
        } break;
            
        case 'q':   // 8: long long / long(64bit) / NSInteger(64bit)
        case 'Q':   // 8: unsigned long long / unsigned long(64bit) / NSUInteger(64bit)
        {
            set_with_args_index(index, long long, longLongValue);
        } break;
            
        case 'f': // 4: float / CGFloat(32bit)
        {
            set_with_args_index(index, float, floatValue);
        } break;
            
        case 'd': // 8: double / CGFloat(64bit)
        case 'D': // 16: long double
        {
            set_with_args_index(index, double, doubleValue);
        } break;
            
        case '*': // char *
        {
            NSString *arg = obj;
            if ([arg isKindOfClass:[NSString class]]) {
                const void *c = [arg UTF8String];
                [self setArgument:&c atIndex:index];
            }
        } break;
            
        case '#': // Class
        {
            NSString *arg = obj;
            if ([arg isKindOfClass:[NSString class]]) {
                Class klass = NSClassFromString(arg);
                if (klass) {
                    [self setArgument:&klass atIndex:index];
                }
            }
        } break;
            
        case '@': // id
        {
            id arg = obj;
            [self setArgument:&arg atIndex:index];
        } break;
            
        case '{': // struct
        {
            if (strcmp(type, @encode(CGPoint)) == 0) {
                if ([obj isKindOfClass:NSString.class]) {
                    CGPoint point = CGPointFromString(obj);
                    [self setArgument:&point atIndex:index];
                } else {
                    CGPoint point = [obj CGPointValue];
                    [self setArgument:&point atIndex:index];
                }
            } else if (strcmp(type, @encode(CGSize)) == 0) {
                if ([obj isKindOfClass:NSString.class]) {
                    CGSize size = CGSizeFromString(obj);
                    [self setArgument:&size atIndex:index];
                } else {
                    CGSize size = [obj CGSizeValue];
                    [self setArgument:&size atIndex:index];
                }
            } else if (strcmp(type, @encode(CGRect)) == 0) {
                if ([obj isKindOfClass:NSString.class]) {
                    CGRect rect = CGRectFromString(obj);
                    [self setArgument:&rect atIndex:index];
                } else {
                    CGRect rect;
                    rect = [obj CGRectValue];
                    [self setArgument:&rect atIndex:index];
                }
            } else if (strcmp(type, @encode(CGVector)) == 0) {
                CGVector vector = {0};
                
                
                NSDictionary *dict = obj;
                set_with_args_struct(dict, vector, dx, @"dx", doubleValue);
                set_with_args_struct(dict, vector, dy, @"dy", doubleValue);
                [self setArgument:&vector atIndex:index];
            } else if (strcmp(type, @encode(CGAffineTransform)) == 0) {
                CGAffineTransform form = {0};
                
                NSDictionary *dict = obj;
                set_with_args_struct(dict, form, a, @"a", doubleValue);
                set_with_args_struct(dict, form, b, @"b", doubleValue);
                set_with_args_struct(dict, form, c, @"c", doubleValue);
                set_with_args_struct(dict, form, d, @"d", doubleValue);
                set_with_args_struct(dict, form, tx, @"tx", doubleValue);
                set_with_args_struct(dict, form, ty, @"ty", doubleValue);
                [self setArgument:&form atIndex:index];
            } else if (strcmp(type, @encode(CATransform3D)) == 0) {
                CATransform3D form3D = {0};
                
                NSDictionary *dict = obj;
                set_with_args_struct(dict, form3D, m11, @"m11", doubleValue);
                set_with_args_struct(dict, form3D, m12, @"m12", doubleValue);
                set_with_args_struct(dict, form3D, m13, @"m13", doubleValue);
                set_with_args_struct(dict, form3D, m14, @"m14", doubleValue);
                set_with_args_struct(dict, form3D, m21, @"m21", doubleValue);
                set_with_args_struct(dict, form3D, m22, @"m22", doubleValue);
                set_with_args_struct(dict, form3D, m23, @"m23", doubleValue);
                set_with_args_struct(dict, form3D, m24, @"m24", doubleValue);
                set_with_args_struct(dict, form3D, m31, @"m31", doubleValue);
                set_with_args_struct(dict, form3D, m32, @"m32", doubleValue);
                set_with_args_struct(dict, form3D, m33, @"m33", doubleValue);
                set_with_args_struct(dict, form3D, m34, @"m34", doubleValue);
                set_with_args_struct(dict, form3D, m41, @"m41", doubleValue);
                set_with_args_struct(dict, form3D, m42, @"m42", doubleValue);
                set_with_args_struct(dict, form3D, m43, @"m43", doubleValue);
                set_with_args_struct(dict, form3D, m44, @"m44", doubleValue);
                [self setArgument:&form3D atIndex:index];
            } else if (strcmp(type, @encode(NSRange)) == 0) {
                if ([obj isKindOfClass:NSString.class]) {
                    NSRange range = NSRangeFromString(obj);
                    [self setArgument:&range atIndex:index];
                } else {
                    NSRange range = [obj rangeValue];
                    [self setArgument:&range atIndex:index];
                }
            } else if (strcmp(type, @encode(UIOffset)) == 0) {
                if ([obj isKindOfClass:NSString.class]) {
                    UIOffset offset = UIOffsetFromString(obj);
                    [self setArgument:&offset atIndex:index];
                } else {
                    UIOffset offset = [obj UIOffsetValue];
                    [self setArgument:&offset atIndex:index];
                }
            } else if (strcmp(type, @encode(UIEdgeInsets)) == 0) {
                if ([obj isKindOfClass:NSString.class]) {
                    UIEdgeInsets insets = UIEdgeInsetsFromString(obj);
                    [self setArgument:&insets atIndex:index];
                } else {
                    UIEdgeInsets insets = [obj UIEdgeInsetsValue];
                    [self setArgument:&insets atIndex:index];
                }
            } else {
                unsupportedType = YES;
            }
        } break;
            
        case '^': // pointer
        {
            unsupportedType = YES;
        } break;
            
        case ':': // SEL
        {
            unsupportedType = YES;
        } break;
            
        case '(': // union
        {
            unsupportedType = YES;
        } break;
            
        case '[': // array
        {
            unsupportedType = YES;
        } break;
            
        default: // what?!
        {
            unsupportedType = YES;
        } break;
    }
    [self retainArguments];
    NSAssert(!unsupportedType, @"arg unsupportedType");
}

- (void)setArguments:(NSArray *)arguments {
    for (int index = 0; index < arguments.count; index++) {
        [self rj_setArgument:arguments[index] atIndex:index];
    }
}

- (NSArray *)arguments {
    return [self arguments_startFromIndex:2];
}

- (NSArray *)arguments_startFromIndex:(NSInteger)index {
    NSMutableArray *argumentsArray = [NSMutableArray array];
    for (NSUInteger idx = index; idx < self.methodSignature.numberOfArguments; idx++) {
        [argumentsArray addObject:[self argumentAtIndex:idx] ?: NSNull.null];
    }
    return [argumentsArray copy];
}

- (id)argumentAtIndex:(NSUInteger)index {
    const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
    // Skip const type qualifier.
    if (argType[0] == _C_CONST) argType++;
    
#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)
    if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing id returnObj;
        [self getArgument:&returnObj atIndex:(NSInteger)index];
        return returnObj;
    } else if (strcmp(argType, @encode(SEL)) == 0) {
        SEL selector = 0;
        [self getArgument:&selector atIndex:(NSInteger)index];
        return NSStringFromSelector(selector);
    } else if (strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing Class theClass = Nil;
        [self getArgument:&theClass atIndex:(NSInteger)index];
        return theClass;
        // Using this list will box the number with the appropriate constructor, instead of the generic NSValue.
    } else if (strcmp(argType, @encode(char)) == 0) {
        WRAP_AND_RETURN(char);
    } else if (strcmp(argType, @encode(int)) == 0) {
        WRAP_AND_RETURN(int);
    } else if (strcmp(argType, @encode(short)) == 0) {
        WRAP_AND_RETURN(short);
    } else if (strcmp(argType, @encode(long)) == 0) {
        WRAP_AND_RETURN(long);
    } else if (strcmp(argType, @encode(long long)) == 0) {
        WRAP_AND_RETURN(long long);
    } else if (strcmp(argType, @encode(unsigned char)) == 0) {
        WRAP_AND_RETURN(unsigned char);
    } else if (strcmp(argType, @encode(unsigned int)) == 0) {
        WRAP_AND_RETURN(unsigned int);
    } else if (strcmp(argType, @encode(unsigned short)) == 0) {
        WRAP_AND_RETURN(unsigned short);
    } else if (strcmp(argType, @encode(unsigned long)) == 0) {
        WRAP_AND_RETURN(unsigned long);
    } else if (strcmp(argType, @encode(unsigned long long)) == 0) {
        WRAP_AND_RETURN(unsigned long long);
    } else if (strcmp(argType, @encode(float)) == 0) {
        WRAP_AND_RETURN(float);
    } else if (strcmp(argType, @encode(double)) == 0) {
        WRAP_AND_RETURN(double);
    } else if (strcmp(argType, @encode(BOOL)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(bool)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(char *)) == 0) {
        WRAP_AND_RETURN(const char *);
    } else if (strcmp(argType, @encode(void (^)(void))) == 0) {
        __unsafe_unretained id block = nil;
        [self getArgument:&block atIndex:(NSInteger)index];
        return [block copy];
    } else if (argType[0] == _C_ID) { // FOR BLOCK ARGUMENT
        __autoreleasing id arg;
        [self getArgument:&arg atIndex:index];
        
        return arg;
    } else {
        NSUInteger valueSize = 0;
        NSGetSizeAndAlignment(argType, &valueSize, NULL);
        
        unsigned char valueBytes[valueSize];
        [self getArgument:valueBytes atIndex:(NSInteger)index];
        
        return [NSValue valueWithBytes:valueBytes objCType:argType];
    }
    return nil;
#undef WRAP_AND_RETURN
}

@end
