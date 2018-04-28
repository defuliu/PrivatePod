//
//  ZGHandlerMsg.h
//  FatDogLogistics
//
//  Created by 刘德福 on 2018/4/28.
//  Copyright © 2018年 Sandy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZGHanlderMsgProtocol.h"

@interface ZGHandlerMsg : NSObject

- (instancetype)initWithModle:(id<ZGHanlderMsgProtocol>)handle;

/**
 消息机制运行时调用类方法
 @param cls class 类名
 @param sel 类方法
 @param param param 以字典形式传入参数
 */
- (void)handlerClassObject:(Class)cls sel:(SEL)sel param:(NSDictionary *)param;

/**
 消息机制运行时调用类方法，获取所需参数
 @param cls  class 类名
 @param sel 类方法
 @param param 以字典形式传入参数
 @return 以字典形式取参
 */
- (NSDictionary *)handlerClassReturnParam:(Class)cls sel:(SEL)sel param:(NSDictionary *)param;

/**
 消息机制运行时调用实例方法
 @param object 已经声明的对象
 @param sel    实例方法
 @param param 以字典形式传入参数
 */
- (void)handlerCallObject:(id)object sel:(SEL)sel param:(NSDictionary *)param;

/**
 消息机制运行时调用实例方法 获取所需参数
 
 @param object 已经声明的对象
 @param sel 实例方法
 @param param 以字典形式传入参数
 @return 以字典形式取参
 */
- (NSDictionary *)handlerCallObjectReturnParam:(id)object sel:(SEL)sel param:(NSDictionary *)param;



@end
