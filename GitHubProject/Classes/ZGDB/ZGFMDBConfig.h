//
//  ZGFMDBConfig.h
//  ZGiOSDevelopment
//
//  Created by 杨佳 on 2018/4/3.
//  Copyright © 2018年 杨佳. All rights reserved.
//

#ifndef ZGFMDBConfig_h
#define ZGFMDBConfig_h

// 过期方法注释
#define ZGFMDBDeprecated(instead) NS_DEPRECATED(2_0, 2_0, 2_0, 2_0, instead)

#define ZG_primaryKey @"ZG_id"
#define ZG_createTimeKey @"ZG_createTime"
#define ZG_updateTimeKey @"ZG_updateTime"

//keyPath查询用的关系，ZG_equal:等于的关系；ZG_contains：包含的关系.
#define ZG_equal @"Relation_Equal"
#define ZG_contains @"Relation_Contains"

#define ZG_complete_B void(^_Nullable)(BOOL isSuccess)
#define ZG_complete_I void(^_Nullable)(ZG_dealState result)
#define ZG_complete_A void(^_Nullable)(NSArray* _Nullable array)
#define ZG_changeBlock void(^_Nullable)(ZG_changeState result)

typedef NS_ENUM(NSInteger,ZG_changeState){//数据改变状态
    ZG_insert,//插入
    ZG_update,//更新
    ZG_delete,//删除
    ZG_drop//删表
};

typedef NS_ENUM(NSInteger,ZG_dealState){//处理状态
    ZG_error = -1,//处理失败
    ZG_incomplete = 0,//处理不完整
    ZG_complete = 1//处理完整
};

typedef NS_ENUM(NSInteger,ZG_sqliteMethodType){//sqlite数据库原生方法枚举
    ZG_min,//求最小值
    ZG_max,//求最大值
    ZG_sum,//求总和值
    ZG_avg//求平均值
};

typedef NS_ENUM(NSInteger,ZG_dataTimeType){
    ZG_createTime,//存储时间
    ZG_updateTime,//更新时间
};

/**
 封装处理传入数据库的key和value.
 */
extern NSString* _Nonnull ZG_sqlKey(NSString* _Nonnull key);
/**
 转换OC对象成数据库数据.
 */
extern NSString* _Nonnull ZG_sqlValue(id _Nonnull value);
/**
 根据keyPath和Value的数组, 封装成数据库语句，来操作库.
 */
extern NSString* _Nonnull ZG_keyPathValues(NSArray* _Nonnull keyPathValues);
/**
 直接执行sql语句;
 @tablename nil时以cla类名为表名.
 @cla 要操作的类,nil时返回的结果是字典.
 */
extern id _Nullable ZG_executeSql(NSString* _Nonnull sql,NSString* _Nullable tablename,__unsafe_unretained _Nullable Class cla);
/**
 自定义数据库名称.
 */
extern void ZG_setSqliteName(NSString*_Nonnull sqliteName);
/**
 删除数据库文件
 */
extern BOOL ZG_deleteSqlite(NSString*_Nonnull sqliteName);
/**
 设置操作过程中不可关闭数据库(即closeDB函数无效).
 默认是NO.
 */
extern void ZG_setDisableCloseDB(BOOL disableCloseDB);
/**
 设置调试模式
 @debug YES:打印调试信息, NO:不打印调试信息.
 */
extern void ZG_setDebug(BOOL debug);

/**
 事务操作.
 return 返回YES提交事务, 返回NO回滚事务.
 */
extern void ZG_inTransaction(BOOL (^ _Nonnull block)(void));

/**
 清除缓存
 */
extern void ZG_cleanCache(void);

#endif /* ZGFMDBConfig_h */
