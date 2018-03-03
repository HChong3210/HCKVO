//
//  NSObject+KVO.m
//  HCKVO
//
//  Created by HChong on 2018/1/26.
//  Copyright © 2018年 HChong. All rights reserved.
//

#import "NSObject+KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation NSObject (KVO)

static NSString *kHCKVOClassPrefix = @"HC";
static const char *kHCKVO_observer_key = "kHCKVO_observer_key";
static const char *kHCKVO_getter_key = "kHCKVO_getter_key";
static const char *kHCKVO_setter_key = "kHCKVO_setter_key";
static const char *kHCKVO_block_key = "kHCKVO_block_key";

//添加一个带block回调的KVO
- (void)HC_addObserver:(NSObject *)observer forKey:(NSString *)key withBlock:(HCObservingBlock)block {
/**
 当你观察一个对象时，会动态的创建一个新的类。这个类继承自该对象的原本的类，并重写了被观察属性的 setter 方法。自然，重写的 setter 方法会负责在调用原 setter 方法之前和之后，通知所有观察对象值的更改。最后把这个对象的 isa 指针 ( isa 指针告诉 Runtime 系统这个对象的类是什么 ) 指向这个新创建的子类，对象就神奇的变成了新创建的子类的实例。原来，这个中间类，继承自原本的那个类。不仅如此，Apple 还重写了 -class 方法，企图欺骗我们这个类没有变，就是原本那个类.
 */

/**
 1.创建注册子类
 2.为新的子类添加set方法
 3.改变isa指针, 指向新的子类
 4.保存set,get方法
 5.保存block
 */
    
    //1.创建注册子类
    //1.1获取被监听对象的类名称
    Class class = object_getClass(self);
    NSString *className = NSStringFromClass(class);
    //1.2检查被检测对象的class的前缀是否被替换过(通过检查前缀来判断), 如果被替换过就说明正在被观测
    if (![className hasPrefix:kHCKVOClassPrefix]) {
        class = [self makeKvoClassWithOriginalClassName:className];
        //为观测的对象设置一个指定的类
        object_setClass(self, class);
    }
    
    //2.为新的子类添加set方法
    //2.1得到Setter方法
    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    //2.2得到指定类的实例方法
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) {
        @throw @"没有对应的Setter方法";
        return;
    }
    //2.3为新类添加set方法
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(class, setterSelector, (IMP)kvo_setter, types);
    }
    
    //3改变isa指针，指向子类
    object_setClass(self, class);
    
    //保存set、get方法名
    objc_setAssociatedObject(self, kHCKVO_getter_key, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, kHCKVO_setter_key, setterForGetter(key), OBJC_ASSOCIATION_COPY_NONATOMIC);
    //保存block
    objc_setAssociatedObject(self, kHCKVO_block_key, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

//相当于重写系统的KVO
- (void)ws_addObserver:(NSObject *_Nonnull)observer forKeyPath:(NSString *_Nonnull)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context {
    //创建、注册子类
    NSString *oldClassName = NSStringFromClass([self class]);
    NSString *newClassName = [NSString stringWithFormat:@"%@%@", kHCKVOClassPrefix, oldClassName];
    
    Class class = objc_getClass(newClassName.UTF8String);
    if (!class) {
        class = objc_allocateClassPair([self class], newClassName.UTF8String, 0);
        objc_registerClassPair(class);
    }
    
    //set方法首字母大写
    NSString *keyPathChange = [[[keyPath substringToIndex:1] uppercaseString] stringByAppendingString:[keyPath substringFromIndex:1]];
    NSString *setNameStr = [NSString stringWithFormat:@"set%@", keyPathChange];
    SEL setSEL = NSSelectorFromString([setNameStr stringByAppendingString:@":"]);
    
    //添加set方法
    Method getMethod = class_getInstanceMethod([self class], @selector(keyPath));
    const char *types = method_getTypeEncoding(getMethod);
    class_addMethod(class, setSEL, (IMP)setMethod, types);
    
    //改变isa指针，指向子类
    object_setClass(self, class);
    
    //保存observer
    objc_setAssociatedObject(self, kHCKVO_observer_key, observer, OBJC_ASSOCIATION_ASSIGN);
    
    //保存set、get方法名
    objc_setAssociatedObject(self, kHCKVO_setter_key, setNameStr, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, kHCKVO_getter_key, keyPath, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

//移除
- (void)HC_removeObserver:(NSObject *)observer forKey:(NSString *)key {
    
}

#pragma mark - Private
//根据原本类, 注册新类, 并且重写新类的class方法
- (Class)makeKvoClassWithOriginalClassName:(NSString *)originalClassName {
    //原始class
    Class originalClass = NSClassFromString(originalClassName);
    //新class
    NSString *kvoClassName = [kHCKVOClassPrefix stringByAppendingString:originalClassName];
    Class kvoClass = NSClassFromString(kvoClassName);
    
    if (!kvoClass) {
        //1.创建新的子类, 继承于原类
        kvoClass = objc_allocateClassPair(originalClass, kvoClassName.UTF8String, 0);
        
        //2.为新的子类添加class方法,
        Method classMethod = class_getInstanceMethod(originalClass, @selector(class));
        const char *types = method_getTypeEncoding(classMethod);
        class_addMethod(kvoClass, @selector(class), (IMP)kvo_class, types);
        
        //3.注册新的子类
        objc_registerClassPair(kvoClass);
    }
    
    return kvoClass;
}

//是否有selector方法
- (BOOL)hasSelector:(SEL)selector {
    Class clazz = object_getClass(self);
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(clazz, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;
}

//重写子类的class方法(kvo_class),指向superclass
static Class kvo_class(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

//根据get得到set方法
static NSString *setterForGetter(NSString *getter) {
    if (getter.length <= 0) {
        return nil;
    }
    NSString *setter = [NSString stringWithFormat:@"set%@:", [getter capitalizedString]];
    return setter;
}

//根据set得到get方法
static NSString *getterForSetter(NSString *setter) {
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    // remove 'set' at the begining and ':' at the end
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *getter = [setter substringWithRange:range];
    
    // lower case the first letter
    NSString *firstLetter = [[getter substringToIndex:1] lowercaseString];
    getter = [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    
    return getter;
}

//新类的set方法
static void kvo_setter(id self, SEL _cmd, id newValue) {
    //包括调用父类的set方法，获取旧值、新值，获取observer并通知observer
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(setterName);
    
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have getter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    /*
     //使用objc_msgSendSuper向父类发消息, 调用父类set方法
    id oldValue = [self valueForKey:getterName];
    
    //superclass
    struct objc_super superclazz = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    // cast our pointer so the compiler won't complain
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    // call super's setter, which is original class's setter method
    objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
     */
    
    
    //保存子类类型
    Class class = [self class];
    //isa指向原类
    object_setClass(self, class_getSuperclass(class));
    //调用原类get方法，获取oldValue
    id oldValue = objc_msgSend(self, NSSelectorFromString(getterName));
    //调用原类set方法
    objc_msgSend(self, _cmd, newValue);
    //isa改回子类类型
    object_setClass(self, class);

    
    //取出block
    HCObservingBlock block = objc_getAssociatedObject(self, kHCKVO_block_key);
    block(self, getterName, oldValue, newValue);
}

static void setMethod (id self, SEL _cmd, id newValue) {
    //获取get、set方法名
    NSString *setNameStr = objc_getAssociatedObject(self, kHCKVO_setter_key);
    NSString *getNameStr = objc_getAssociatedObject(self, kHCKVO_getter_key);
    
    //保存子类类型
    Class class = [self class];
    
    //isa指向原类
    object_setClass(self, class_getSuperclass(class));
    
    //调用原类get方法，获取oldValue
    id oldValue = objc_msgSend(self, NSSelectorFromString(getNameStr));
    
    //调用原类set方法
    objc_msgSend(self, NSSelectorFromString([setNameStr stringByAppendingString:@":"]), newValue);
    
    //调用observer的observeValueForKeyPath: ofObject: change: context:方法
    id observer = objc_getAssociatedObject(self, kHCKVO_observer_key);
    
    NSMutableDictionary *change = @{}.mutableCopy;
    if (newValue) {
        change[NSKeyValueChangeNewKey] = newValue;
    }
    if (oldValue) {
        change[NSKeyValueChangeOldKey] = oldValue;
    }
    
    objc_msgSend(observer, @selector(observeValueForKeyPath: ofObject: change: context:), getNameStr, self, change, nil);
    
    //isa改回子类类型
    object_setClass(self, class);
}

@end
