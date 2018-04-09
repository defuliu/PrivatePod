//
//  ZGDBModelInfo.m
//  ZGiOSDevelopment
//
//  Created by 杨佳 on 2018/4/3.
//  Copyright © 2018年 杨佳. All rights reserved.
//

#import "ZGDBModelInfo.h"
#import "ZGDBTool.h"
#import "ZGFMDBConfig.h"

@implementation ZGDBModelInfo

+(NSArray<ZGDBModelInfo*>*)modelInfoWithObject:(id)object{
    NSMutableArray* modelInfos = [NSMutableArray array];
    NSArray* keyAndTypes = [ZGDBTool getClassIvarList:[object class] Object:object onlyKey:NO];
    for(NSString* keyAndType in keyAndTypes){
        NSArray* keyTypes = [keyAndType componentsSeparatedByString:@"*"];
        NSString* propertyName = keyTypes[0];
        NSString* propertyType = keyTypes[1];
        
        ZGDBModelInfo* info = [ZGDBModelInfo new];
        //设置属性名
        [info setValue:propertyName forKey:@"propertyName"];
        //设置属性类型
        [info setValue:propertyType forKey:@"propertyType"];
        //设置列名(ZG_ + 属性名),加ZG_是为了防止和数据库关键字发生冲突.
        [info setValue:[NSString stringWithFormat:@"%@",propertyName] forKey:@"sqlColumnName"];
        //设置列属性
        NSString* sqlType = [ZGDBTool getSqlType:propertyType];
        [info setValue:sqlType forKey:@"sqlColumnType"];
        
        id propertyValue;
        id sqlValue;
        //crateTime和updateTime两个额外字段单独处理.
        if([propertyName isEqualToString:ZG_createTimeKey] ||
           [propertyName isEqualToString:ZG_updateTimeKey]){
            propertyValue = [ZGDBTool stringWithDate:[NSDate new]];
        }else{
            propertyValue = [object valueForKey:propertyName];
        }
        
        if(propertyValue){
            //设置属性值
            [info setValue:propertyValue forKey:@"propertyValue"];
            sqlValue = [ZGDBTool getSqlValue:propertyValue type:propertyType encode:YES];
            [info setValue:sqlValue forKey:@"sqlColumnValue"];
            [modelInfos addObject:info];
        }
        
    }
    NSAssert(modelInfos.count,@"对象变量数据为空,不能存储!");
    return modelInfos;
}

@end
