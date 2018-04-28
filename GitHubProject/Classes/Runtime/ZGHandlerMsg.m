//
//  ZGHandlerMsg.m
//  FatDogLogistics
//
//  Created by 刘德福 on 2018/4/28.
//  Copyright © 2018年 Sandy. All rights reserved.
//

#import "ZGHandlerMsg.h"
#import "ZGHandlerMsgMediator.h"

@interface ZGHandlerMsg ()

@property (nonatomic, strong) id <ZGHanlderMsgProtocol> hanlder;

@end

@implementation ZGHandlerMsg


- (instancetype)initWithModle:(id<ZGHanlderMsgProtocol>)handle
{
    self = [super init];
    if (self) {
        self.hanlder = handle;
    }
    return self;
}

- (void)handlerClassObject:(Class)cls sel:(SEL)sel param:(NSDictionary *)param
{
    return [self.hanlder handlerClassAddParam:cls performSelector:sel param:param];
}

- (NSDictionary *)handlerClassReturnParam:(Class)cls sel:(SEL)sel param:(NSDictionary *)param
{
    [self.hanlder handlerClassRetrunParam:cls performSelector:sel param:param];
    return param;
}

- (void)handlerCallObject:(id)object sel:(SEL)sel param:(NSDictionary *)param
{
    [self.hanlder handlerNoApplyMemoryObject:object performSelector:sel param:param];
}

- (NSDictionary *)handlerCallObjectReturnParam:(id)object sel:(SEL)sel param:(NSDictionary *)param
{
    [self.hanlder handlerNoMemory:object performSelector:sel param:param];
    return param;
}




@end
