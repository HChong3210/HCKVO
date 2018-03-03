//
//  NSObject+KVO.h
//  HCKVO
//
//  Created by HChong on 2018/1/26.
//  Copyright © 2018年 HChong. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^HCObservingBlock)(id _Nullable observedObject, NSString * _Nullable observedKey, id _Nullable oldValue, id _Nullable newValue);

@interface NSObject (KVO)

//添加带block回调的KVO
- (void)HC_addObserver:(NSObject *_Nullable)observer forKey:(NSString *_Nullable)key withBlock:(HCObservingBlock _Nullable )block;

//移除带block回调的KVO
- (void)HC_removeObserver:(NSObject *_Nullable)observer forKey:(NSString *_Nullable)key;


- (void)ws_addObserver:(NSObject *_Nonnull)observer forKeyPath:(NSString *_Nonnull)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;
@end
