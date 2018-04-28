//
//  ZGHandlerMsgMediator.m
//  FatDogLogistics
//
//  Created by 刘德福 on 2018/4/28.
//  Copyright © 2018年 Sandy. All rights reserved.
//

#import "ZGHandlerMsgMediator.h"
#include <objc/message.h>

@implementation ZGHandlerMsgMediator

//无需声明内存，带参数
- (void)handlerNoApplyMemoryObject:(id)object performSelector:(SEL)sel param:(NSDictionary *)dict
{
    void(*handleAction)(id,SEL,NSDictionary *) = (void (*)(id,SEL,NSDictionary *))objc_msgSend;
    handleAction(object,sel,dict);
}


/** runtime 不需申请内存 return param*/
- (NSDictionary *)handlerNoApplyMemory:(id)objc performSelector:(SEL)sel  param:(NSDictionary*)param
{
    void(*handleAction)(id,SEL,NSDictionary *) = (void (*)(id,SEL,NSDictionary *))objc_msgSend;
    handleAction(objc,sel,param);
    return param;
}

#pragma mark - 类方处理
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
/** runtime 调用类方法带参数*/
- (void)handlerClassAddParam:(Class)cls performSelector:(SEL)sel param:(id)param
{
    [cls performSelector:sel withObject:param];
}

/** runtime 调用类方法返回参数*/
- (id)handlerClassRetrunParam:(Class)cls performSelector:(SEL)sel param:(id)param
{
    [cls performSelector:sel withObject:param];
    return param;
}

#pragma clang diagnostic pop

@end


