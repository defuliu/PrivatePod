//
//  NSCache+ZGCache.m
//  ZGiOSDevelopment
//
//  Created by 杨佳 on 2018/4/3.
//  Copyright © 2018年 杨佳. All rights reserved.
//

#import "NSCache+ZGCache.h"

static NSCache* keyCaches;
@implementation NSCache (ZGCache)

+(instancetype)ZG_cache{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyCaches = [NSCache new];
    });
    return keyCaches;
}

@end
