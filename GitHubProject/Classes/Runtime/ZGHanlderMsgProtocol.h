//
//  ZGHanlderMsgProtocol.h
//  FatDogLogistics
//
//  Created by 刘德福 on 2018/4/28.
//  Copyright © 2018年 Sandy. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ZGHanlderMsgProtocol <NSObject>

@optional

#pragma mark - 实例方法
/** runtime 调用对象方法，无需申请内存,带参数*/
- (void)handlerNoApplyMemoryObject:(id)object performSelector:(SEL)sel param:(NSDictionary *)dict;
/** runtime return param*/
- (NSDictionary *)handlerNoMemory:(id)objc  performSelector:(SEL)sel  param:(NSDictionary*)param;

#pragma mark - 处理类方法
/** runtime 调用类方法带参数*/
- (void)handlerClassAddParam:(Class)cls performSelector:(SEL)sel param:(id)param;
/** runtime 调用类方法返回参数*/
- (id)handlerClassRetrunParam:(Class)cls performSelector:(SEL)sel param:(id)param;

@end
