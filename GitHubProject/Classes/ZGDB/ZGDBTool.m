//
//  ZGDBTool.m
//  ZGiOSDevelopment
//
//  Created by 杨佳 on 2018/4/3.
//  Copyright © 2018年 杨佳. All rights reserved.
//

#import "ZGDBTool.h"
#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>
#import "ZGMainDB.h"
#import "ZGDBModelInfo.h"
#import "NSCache+ZGCache.h"
#import<objc/runtime.h>

#define SqlText @"text" //数据库的字符类型
#define SqlReal @"real" //数据库的浮点类型
#define SqlInteger @"integer" //数据库的整数类型
//#define SqlBlob @"blob" //数据库的二进制类型

#define ZGValue @"ZGValue"
#define ZGData @"ZGData"
#define ZGArray @"ZGArray"
#define ZGSet @"ZGSet"
#define ZGDictionary @"ZGDictionary"
#define ZGModel @"ZGModel"
#define ZGMapTable @"ZGMapTable"
#define ZGHashTable @"ZGHashTable"

//100M大小限制.
#define MaxData @(838860800)

/**
 *  遍历所有类的block（父类）
 */
typedef void (^ZGClassesEnumeration)(Class c, BOOL *stop);
static NSSet *foundationClasses_;

@implementation ZGDBTool

/**
 封装处理传入数据库的key和value.
 */
NSString* ZG_sqlKey(NSString* key){
    return [NSString stringWithFormat:@"%@",key];
}

/**
 转换OC对象成数据库数据.
 */
NSString* ZG_sqlValue(id value){
    
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    
    NSString* type = [NSString stringWithFormat:@"@\"%@\"",NSStringFromClass([value class])];
    value = [ZGDBTool getSqlValue:value type:type encode:YES];
    if ([value isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"'%@'",value];
    }else{
        return value;
    }
    
}

/**
 根据keyPath和Value的数组, 封装成数据库语句，来操作库.
 */
NSString* ZG_keyPathValues(NSArray* keyPathValues){
    return [ZGDBTool getLikeWithKeyPathAndValues:keyPathValues where:NO];
}
/**
 自定义数据库名称.
 */
void ZG_setSqliteName(NSString*_Nonnull sqliteName){
    if (![sqliteName isEqualToString:[ZGMainDB shareManager].sqliteName]) {
        [ZGMainDB shareManager].sqliteName = sqliteName;
    }
}
/**
 删除数据库文件
 */
BOOL ZG_deleteSqlite(NSString*_Nonnull sqliteName){
    return [ZGMainDB deleteSqlite:sqliteName];
}
/**
 设置操作过程中不可关闭数据库(即closeDB函数无效).
 默认是NO.
 */
void ZG_setDisableCloseDB(BOOL disableCloseDB){
    if ([ZGMainDB shareManager].disableCloseDB != disableCloseDB){//防止重复设置.
        [ZGMainDB shareManager].disableCloseDB = disableCloseDB;
    }
}
/**
 设置调试模式
 @debug YES:打印调试信息, NO:不打印调试信息.
 */
void ZG_setDebug(BOOL debug){
    if ([ZGMainDB shareManager].debug != debug){//防止重复设置.
        [ZGMainDB shareManager].debug = debug;
    }
}

/**
 事务操作.
 @return 返回YES提交事务, 返回NO回滚事务.
 */
void ZG_inTransaction(BOOL (^ _Nonnull block)(void)){
    [[ZGMainDB shareManager] inTransaction:block];
}
/**
 清除缓存
 */
void ZG_cleanCache(){
    [[NSCache ZG_cache] removeAllObjects];
}
/**
 json字符转json格式数据 .
 */
+(id)jsonWithString:(NSString*)jsonString {
    NSAssert(jsonString,@"数据不能为空!");
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    id dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                             options:NSJSONReadingMutableContainers
                                               error:&err];
    
    NSAssert(!err,@"json解析失败");
    return dic;
}
/**
 字典转json字符 .
 */
+(NSString*)dataToJson:(id)data{
    NSAssert(data,@"数据不能为空!");
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (NSSet *)foundationClasses
{
    if (foundationClasses_ == nil) {
        // 集合中没有NSObject，因为几乎所有的类都是继承自NSObject，具体是不是NSObject需要特殊判断
        foundationClasses_ = [NSSet setWithObjects:
                              [NSURL class],
                              [NSDate class],
                              [NSValue class],
                              [NSData class],
                              [NSError class],
                              [NSArray class],
                              [NSDictionary class],
                              [NSString class],
                              [NSAttributedString class], nil];
    }
    return foundationClasses_;
}

+ (void)ZG_enumerateClasses:(__unsafe_unretained Class)srcCla complete:(ZGClassesEnumeration)enumeration
{
    // 1.没有block就直接返回
    if (enumeration == nil) return;
    // 2.停止遍历的标记
    BOOL stop = NO;
    // 3.当前正在遍历的类
    Class c = srcCla;
    // 4.开始遍历每一个类
    while (c && !stop) {
        // 4.1.执行操作
        enumeration(c, &stop);
        // 4.2.获得父类
        c = class_getSuperclass(c);
        if ([self isClassFromFoundation:c]) break;
    }
}

+ (BOOL)isClassFromFoundation:(Class)c
{
    if (c == [NSObject class] || c == [NSManagedObject class]) return YES;
    __block BOOL result = NO;
    [[self foundationClasses] enumerateObjectsUsingBlock:^(Class foundationClass, BOOL *stop) {
        if ([c isSubclassOfClass:foundationClass]) {
            result = YES;
            *stop = YES;
        }
    }];
    return result;
}


/**
 根据类获取变量名列表
 @onlyKey YES:紧紧返回key,NO:在key后面添加type.
 */
+(NSArray*)getClassIvarList:(__unsafe_unretained Class)cla Object:(_Nullable id)object onlyKey:(BOOL)onlyKey{
    
    //获取缓存的属性信息
    NSCache* cache = [NSCache ZG_cache];
    NSString* cacheKey;
    cacheKey = onlyKey?[NSString stringWithFormat:@"%@_IvarList_yes",NSStringFromClass(cla)]:[NSString stringWithFormat:@"%@_IvarList_no",NSStringFromClass(cla)];
    NSArray* cachekeys = [cache objectForKey:cacheKey];
    if(cachekeys){
        return cachekeys;
    }
    
    NSMutableArray* keys = [NSMutableArray array];
    if(onlyKey){
        [keys addObject:ZG_primaryKey];
        [keys addObject:ZG_createTimeKey];
        [keys addObject:ZG_updateTimeKey];
    }else{
        //手动添加库自带的自动增长主键ID和类型q
        [keys addObject:[NSString stringWithFormat:@"%@*q",ZG_primaryKey]];
        //建表时此处加入额外的两个字段(createTime和updateTime).
        [keys addObject:[NSString stringWithFormat:@"%@*@\"NSString\"",ZG_createTimeKey]];
        [keys addObject:[NSString stringWithFormat:@"%@*@\"NSString\"",ZG_updateTimeKey]];
    }
    
    [self ZG_enumerateClasses:cla complete:^(__unsafe_unretained Class c, BOOL *stop) {
        unsigned int numIvars; //成员变量个数
        Ivar *vars = class_copyIvarList(c, &numIvars);
        for(int i = 0; i < numIvars; i++) {
            Ivar thisIvar = vars[i];
            NSString* key = [NSString stringWithUTF8String:ivar_getName(thisIvar)];//获取成员变量的名
            if ([key hasPrefix:@"_"]) {
                key = [key substringFromIndex:1];
            }
            if (!onlyKey) {
                //获取成员变量的数据类型
                NSString* type = [NSString stringWithUTF8String:ivar_getTypeEncoding(thisIvar)];
                key = [NSString stringWithFormat:@"%@*%@",key,type];
            }
            [keys addObject:key];//存储对象的变量名
        }
        free(vars);//释放资源
    }];
    
    [cache setObject:keys forKey:cacheKey];
    
    return keys;
}

/**
 抽取封装条件数组处理函数
 */
+(NSArray*)where:(NSArray*)where{
    NSMutableArray* results = [NSMutableArray array];
    NSMutableString* SQL = [NSMutableString string];
    if(!(where.count%3)){
        [SQL appendString:@" where "];
        for(int i=0;i<where.count;i+=3){
            [SQL appendFormat:@"%@%@?",where[i],where[i+1]];
            if (i != (where.count-3)) {
                [SQL appendString:@" and "];
            }
        }
    }else{
        //NSLog(@"条件数组错误!");
        NSAssert(NO,@"条件数组错误!");
    }
    NSMutableArray* wheres = [NSMutableArray array];
    for(int i=0;i<where.count;i+=3){
        [wheres addObject:where[i+2]];
    }
    [results addObject:SQL];
    [results addObject:wheres];
    return results;
}
/**
 封装like语句获取函数
 */
+(NSString*)getLikeWithKeyPathAndValues:(NSArray* _Nonnull)keyPathValues where:(BOOL)where{
    NSAssert(keyPathValues,@"集合不能为空!");
    NSAssert(!(keyPathValues.count%3),@"集合格式错误!");
    NSMutableArray* keys = [NSMutableArray array];
    NSMutableArray* values = [NSMutableArray array];
    NSMutableArray* relations = [NSMutableArray array];
    for(int i=0;i<keyPathValues.count;i+=3){
        [keys addObject:keyPathValues[i]];
        [relations addObject:keyPathValues[i+1]];
        [values addObject:keyPathValues[i+2]];
    }
    NSMutableString* likeM = [NSMutableString string];
    !where?:[likeM appendString:@" where "];
    NSInteger keysCount = keys.count;
    for(int i=0;i<keysCount;i++){
        BOOL likeOr = NO;
        NSString* keyPath = keys[i];
        id value = values[i];
        NSAssert([keyPath containsString:@"."], @"keyPath错误,正确形式如: user.stident.name");
        NSArray* keypaths = [keyPath componentsSeparatedByString:@"."];
        NSMutableString* keyPathParam = [NSMutableString string];
        for(int i=1;i<keypaths.count;i++){
            i!=1?:[keyPathParam appendString:@"%"];
            [keyPathParam appendFormat:@"%@",keypaths[i]];
            [keyPathParam appendString:@"%"];
        }
        //[keyPathParam appendFormat:@"%@",value];
        if ([relations[i] isEqualToString:ZG_contains]){//包含关系
            if(![value isKindOfClass:[NSString class]]){
                NSAssert(NO, @"非字符串不能设置包含关系!");
            }
            [keyPathParam appendFormat:@"%@",value];
            [keyPathParam appendString:@"%"];
        }else{
            
            if([value isKindOfClass:[NSString class]]){
                [keyPathParam appendFormat:@"\"%@",value];
            }else{
                [keyPathParam appendFormat:@": %@",value];
            }
            
            if(keypaths.count<=2){
                if([value isKindOfClass:[NSString class]]){
                    [keyPathParam appendString:@"\"%"];
                }else{
                    [keyPathParam appendString:@",%"];
                    likeOr = YES;
                }
            }else{
                if([value isKindOfClass:[NSString class]]){
                    [keyPathParam appendString:@"\\%"];
                }else{
                    [keyPathParam appendString:@",%"];
                    likeOr = YES;
                }
            }
        }
        if(likeOr){
            if(keypaths.count<=2){
                [likeM appendFormat:@"((%@ like '%@') or (%@ like '%@'))",keypaths[0],keyPathParam,keypaths[0],[keyPathParam stringByReplacingOccurrencesOfString:@"," withString:@"\n}"]];
            }else{
                [likeM appendFormat:@"((%@ like '%@') or (%@ like '%@'))",keypaths[0],keyPathParam,keypaths[0],[keyPathParam stringByReplacingOccurrencesOfString:@"," withString:@"\\"]];
            }
        }else{
            [likeM appendFormat:@"%@ like '%@'",keypaths[0],keyPathParam];
        }
        if(i != (keys.count-1)){
            [likeM appendString:@" and "];
        }
    }
    return likeM;
}

/**
 判断是不是 "唯一约束" 字段.
 */
+(BOOL)isUniqueKey:(NSString*)uniqueKey with:(NSString*)param{
    NSArray* array = [param componentsSeparatedByString:@"*"];
    NSString* key = array[0];
    return [uniqueKey isEqualToString:key];
}
/**
 判断并获取字段类型
 */
+(NSString*)keyAndType:(NSString*)param{
    NSArray* array = [param componentsSeparatedByString:@"*"];
    NSString* key = array[0];
    NSString* type = array[1];
    NSString* SqlType;
    type = [self getSqlType:type];
    if ([SqlText isEqualToString:type]) {
        SqlType = SqlText;
    }else if ([SqlReal isEqualToString:type]){
        SqlType = SqlReal;
    }else if ([SqlInteger isEqualToString:type]){
        SqlType = SqlInteger;
    }else{
        NSAssert(NO,@"没有找到匹配的类型!");
    }
    //设置列名(ZG_ + 属性名),加ZG_是为了防止和数据库关键字发生冲突.
    return [NSString stringWithFormat:@"%@ %@",[NSString stringWithFormat:@"%@",key],SqlType];
}

+(NSString*)getSqlType:(NSString*)type{
    if([type isEqualToString:@"i"]||[type isEqualToString:@"I"]||
       [type isEqualToString:@"s"]||[type isEqualToString:@"S"]||
       [type isEqualToString:@"q"]||[type isEqualToString:@"Q"]||
       [type isEqualToString:@"b"]||[type isEqualToString:@"B"]||
       [type isEqualToString:@"c"]||[type isEqualToString:@"C"]|
       [type isEqualToString:@"l"]||[type isEqualToString:@"L"]) {
        return SqlInteger;
    }else if([type isEqualToString:@"f"]||[type isEqualToString:@"F"]||
             [type isEqualToString:@"d"]||[type isEqualToString:@"D"]){
        return SqlReal;
    }else{
        return SqlText;
    }
}
//对象转json字符
+(NSString *)jsonStringWithObject:(id)object{
    NSMutableDictionary* keyValueDict = [NSMutableDictionary dictionary];
    NSArray* keyAndTypes = [ZGDBTool getClassIvarList:[object class] Object:object onlyKey:NO];
    for(NSString* keyAndType in keyAndTypes){
        NSArray* arr = [keyAndType componentsSeparatedByString:@"*"];
        NSString* propertyName = arr[0];
        NSString* propertyType = arr[1];
        if(![propertyName isEqualToString:ZG_primaryKey]){
            id propertyValue = [object valueForKey:propertyName];
            if (propertyValue){
                id Value = [self getSqlValue:propertyValue type:propertyType encode:YES];
                keyValueDict[propertyName] = Value;
            }
        }
    }
    return [self dataToJson:keyValueDict];
}
//根据value类型返回用于数组插入数据库的NSDictionary
+(NSDictionary*)dictionaryForArrayInsert:(id)value{
    
    if ([value isKindOfClass:[NSArray class]]){
        return @{ZGArray:[self jsonStringWithArray:value]};
    }else if ([value isKindOfClass:[NSSet class]]){
        return @{ZGSet:[self jsonStringWithArray:value]};
    }else if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]){
        return @{ZGValue:value};
    }else if([value isKindOfClass:[NSData class]]){
        NSData* data = value;
        NSNumber* maxLength = MaxData;
        NSAssert(data.length<maxLength.integerValue,@"最大存储限制为100M");
        return @{ZGData:[value base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength]};
    }else if ([value isKindOfClass:[NSDictionary class]]){
        return @{ZGDictionary:[self jsonStringWithDictionary:value]};
    }else if ([value isKindOfClass:[NSMapTable class]]){
        return @{ZGMapTable:[self jsonStringWithMapTable:value]};
    }else if([value isKindOfClass:[NSHashTable class]]){
        return @{ZGHashTable:[self jsonStringWithNSHashTable:value]};
    }else{
        NSString* modelKey = [NSString stringWithFormat:@"%@*%@",ZGModel,NSStringFromClass([value class])];
        return @{modelKey:[self jsonStringWithObject:value]};
    }
    
}
//NSArray,NSSet转json字符
+(NSString*)jsonStringWithArray:(id)array{
    if ([NSJSONSerialization isValidJSONObject:array]) {
        return [self dataToJson:array];
    }else{
        NSMutableArray* arrM = [NSMutableArray array];
        for(id value in array){
            [arrM addObject:[self dictionaryForArrayInsert:value]];
        }
        return [self dataToJson:arrM];
    }
}

//根据value类型返回用于字典插入数据库的NSDictionary
+(NSDictionary*)dictionaryForDictionaryInsert:(id)value{
    if ([value isKindOfClass:[NSArray class]]){
        return @{ZGArray:[self jsonStringWithArray:value]};
    }else if ([value isKindOfClass:[NSSet class]]){
        return @{ZGSet:[self jsonStringWithArray:value]};
    }else if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]){
        return @{ZGValue:value};
    }else if([value isKindOfClass:[NSData class]]){
        NSData* data = value;
        NSNumber* maxLength = MaxData;
        NSAssert(data.length<maxLength.integerValue,@"最大存储限制为100M");
        return @{ZGData:[value base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength]};
    }else if ([value isKindOfClass:[NSDictionary class]]){
        return @{ZGDictionary:[self jsonStringWithDictionary:value]};
    }else if ([value isKindOfClass:[NSMapTable class]]){
        return @{ZGMapTable:[self jsonStringWithMapTable:value]};
    }else if ([value isKindOfClass:[NSHashTable class]]){
        return @{ZGHashTable:[self jsonStringWithNSHashTable:value]};
    }else{
        NSString* modelKey = [NSString stringWithFormat:@"%@*%@",ZGModel,NSStringFromClass([value class])];
        return @{modelKey:[self jsonStringWithObject:value]};
    }
}
//字典转json字符串.
+(NSString*)jsonStringWithDictionary:(NSDictionary*)dictionary{
    if ([NSJSONSerialization isValidJSONObject:dictionary]) {
        return [self dataToJson:dictionary];
    }else{
        NSMutableDictionary* dictM = [NSMutableDictionary dictionary];
        for(NSString* key in dictionary.allKeys){
            dictM[key] = [self dictionaryForDictionaryInsert:dictionary[key]];
        }
        return [self dataToJson:dictM];
    }
    
}
//NSMapTable转json字符串.
+(NSString*)jsonStringWithMapTable:(NSMapTable*)mapTable{
    NSMutableDictionary* dictM = [NSMutableDictionary dictionary];
    NSArray* objects = mapTable.objectEnumerator.allObjects;
    NSArray* keys = mapTable.keyEnumerator.allObjects;
    for(int i=0;i<objects.count;i++){
        NSString* key = keys[i];
        id object = objects[i];
        dictM[key] = [self dictionaryForDictionaryInsert:object];
    }
    return [self dataToJson:dictM];
}
//NSHashTable转json字符串.
+(NSString*)jsonStringWithNSHashTable:(NSHashTable*)hashTable{
    NSMutableArray* arrM = [NSMutableArray array];
    NSArray* values = hashTable.objectEnumerator.allObjects;
    for(id value in values){
        [arrM addObject:[self dictionaryForArrayInsert:value]];
    }
    return  [self dataToJson:arrM];
}
//NSDate转字符串,格式: yyyy-MM-dd HH:mm:ss
+(NSString*)stringWithDate:(NSDate*)date{
    NSDateFormatter* formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:date];
}
//跟value和数据类型type 和编解码标志 返回编码插入数据库的值,或解码数据库的值.
+(id)getSqlValue:(id)value type:(NSString*)type encode:(BOOL)encode{
    if(!value || [value isKindOfClass:[NSNull class]])return nil;
    
    if([type containsString:@"String"]){
        if([type containsString:@"AttributedString"]){//处理富文本.
            if(encode) {
                return [[NSKeyedArchiver archivedDataWithRootObject:value] base64EncodedDataWithOptions:NSDataBase64Encoding64CharacterLineLength];
            }else{
                NSData* data = [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters];
                return [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
        }else{
            return value;
        }
    }else if([type containsString:@"Number"]){
        if(encode) {
            return [NSString stringWithFormat:@"%@",value];
        }else{
            return [[NSNumberFormatter new] numberFromString:value];
        }
    }else if([type containsString:@"Array"]){
        if(encode){
            return [self jsonStringWithArray:value];
        }else{
            return [self arrayFromJsonString:value];
        }
    }else if([type containsString:@"Dictionary"]){
        if(encode){
            return [self jsonStringWithDictionary:value];
        }else{
            return [self dictionaryFromJsonString:value];
        }
    }else if([type containsString:@"Set"]){
        if(encode){
            return [self jsonStringWithArray:value];
        }else{
            return [self arrayFromJsonString:value];
        }
    }else if([type containsString:@"Data"]){
        if(encode){
            NSData* data = value;
            NSNumber* maxLength = MaxData;
            NSAssert(data.length<maxLength.integerValue,@"最大存储限制为100M");
            return [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        }else{
            return [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters];
        }
    }else if([type containsString:@"NSMapTable"]){
        if(encode){
            return [self jsonStringWithMapTable:value];
        }else{
            return [self mapTableFromJsonString:value];
        }
    }else if ([type containsString:@"NSHashTable"]){
        if(encode){
            return [self jsonStringWithNSHashTable:value];
        }else{
            return [self hashTableFromJsonString:value];
        }
    }else if ([type containsString:@"NSDate"]){
        if(encode){
            return [self stringWithDate:value];
        }else{
            return [self dateFromString:value];
        }
    }else if ([type containsString:@"NSURL"]){
        if(encode){
            return [value absoluteString];
        }else{
            return [NSURL URLWithString:value];
        }
    }else if ([type containsString:@"UIImage"]){
        if(encode){
            NSData* data = UIImageJPEGRepresentation(value, 1);
            NSNumber* maxLength = MaxData;
            NSAssert(data.length<maxLength.integerValue,@"最大存储限制为100M");
            return [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        }else{
            return [UIImage imageWithData:[[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters]];
        }
    }else if ([type containsString:@"UIColor"]){
        if(encode){
            CGFloat r, g, b, a;
            [value getRed:&r green:&g blue:&b alpha:&a];
            return [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f", r, g, b, a];
        }else{
            NSArray<NSString*>* arr = [value componentsSeparatedByString:@","];
            return [UIColor colorWithRed:arr[0].floatValue green:arr[1].floatValue blue:arr[2].floatValue alpha:arr[3].floatValue];
        }
    }else if ([type containsString:@"NSRange"]){
        if(encode){
            return NSStringFromRange([value rangeValue]);
        }else{
            return [NSValue valueWithRange:NSRangeFromString(value)];
        }
    }else if ([type containsString:@"CGRect"]&&[type containsString:@"CGPoint"]&&[type containsString:@"CGSize"]){
        if(encode){
            return NSStringFromCGRect([value CGRectValue]);
        }else{
            return [NSValue valueWithCGRect:CGRectFromString(value)];
        }
    }else if (![type containsString:@"CGRect"]&&[type containsString:@"CGPoint"]&&![type containsString:@"CGSize"]){
        if(encode){
            return NSStringFromCGPoint([value CGPointValue]);
        }else{
            return [NSValue valueWithCGPoint:CGPointFromString(value)];
        }
    }else if (![type containsString:@"CGRect"]&&![type containsString:@"CGPoint"]&&[type containsString:@"CGSize"]){
        if(encode){
            return NSStringFromCGSize([value CGSizeValue]);
        }else{
            return [NSValue valueWithCGSize:CGSizeFromString(value)];
        }
    }else if([type isEqualToString:@"i"]||[type isEqualToString:@"I"]||
             [type isEqualToString:@"s"]||[type isEqualToString:@"S"]||
             [type isEqualToString:@"q"]||[type isEqualToString:@"Q"]||
             [type isEqualToString:@"b"]||[type isEqualToString:@"B"]||
             [type isEqualToString:@"c"]||[type isEqualToString:@"C"]||
             [type isEqualToString:@"l"]||[type isEqualToString:@"L"]){
        return value;
    }else if([type isEqualToString:@"f"]||[type isEqualToString:@"F"]||
             [type isEqualToString:@"d"]||[type isEqualToString:@"D"]){
        return value;
    }else{
        if(encode){
            return [self jsonStringWithArray:@[value]];
        }else{
            return [self arrayFromJsonString:value].firstObject;
        }
    }
}
/**
 判断系统类型与否
 */
+(BOOL)isKindOfSystemType:(NSString*)type{
    
    if([type containsString:@"String"]||
       [type containsString:@"Number"]||
       [type containsString:@"Array"]||
       [type containsString:@"Dictionary"]||
       [type containsString:@"Set"]||
       [type containsString:@"Data"]||
       [type containsString:@"NSMapTable"]||
       [type containsString:@"NSHashTable"]||
       [type containsString:@"NSDate"]||
       [type containsString:@"NSURL"]||
       [type containsString:@"UIImage"]||
       [type containsString:@"UIColor"]||
       [type containsString:@"NSRange"]||
       ([type containsString:@"CGRect"]&&[type containsString:@"CGPoint"]&&[type containsString:@"CGSize"])||
       (![type containsString:@"CGRect"]&&[type containsString:@"CGPoint"]&&![type containsString:@"CGSize"])||
       (![type containsString:@"CGRect"]&&![type containsString:@"CGPoint"]&&[type containsString:@"CGSize"])||
       [type isEqualToString:@"i"]||[type isEqualToString:@"I"]||
       [type isEqualToString:@"s"]||[type isEqualToString:@"S"]||
       [type isEqualToString:@"q"]||[type isEqualToString:@"Q"]||
       [type isEqualToString:@"b"]||[type isEqualToString:@"B"]||
       [type isEqualToString:@"c"]||[type isEqualToString:@"C"]||
       [type isEqualToString:@"l"]||[type isEqualToString:@"L"]||
       [type isEqualToString:@"f"]||[type isEqualToString:@"F"]||
       [type isEqualToString:@"d"]||[type isEqualToString:@"D"]){
        return YES;
    }else{
        return NO;
    }
}

/**
 根据传入的对象获取表名.
 */
+(NSString *)getTableNameWithObject:(id)object{
    NSString* tablename = [object valueForKey:ZG_tableNameKey];
    if(tablename == nil) {
        tablename = NSStringFromClass([object class]);
    }
    return tablename;
}
/**
 存储转换用的字典转化成对象处理函数.
 */
+(id)objectFromJsonStringWithTableName:(NSString* _Nonnull)tablename class:(__unsafe_unretained _Nonnull Class)cla valueDict:(NSDictionary*)valueDict{
    id object = [cla new];
    NSMutableArray* valueDictKeys = [NSMutableArray arrayWithArray:valueDict.allKeys];
    NSMutableArray* keyAndTypes = [NSMutableArray arrayWithArray:[self getClassIvarList:cla Object:nil onlyKey:NO]];
    
    for(int i=0;i<valueDictKeys.count;i++){
        NSString* sqlKey = valueDictKeys[i];
        NSString* tempSqlKey = sqlKey;
        for(NSString* keyAndType in keyAndTypes){
            NSArray* arrKT = [keyAndType componentsSeparatedByString:@"*"];
            NSString* key = [arrKT firstObject];
            NSString* type = [arrKT lastObject];
            
            if ([tempSqlKey isEqualToString:key]){
                NSString* tempValue = valueDict[sqlKey];
                id ivarValue = [self getSqlValue:tempValue type:type encode:NO];
                !ivarValue?:[object setValue:ivarValue forKey:key];
                [keyAndTypes removeObject:keyAndType];
                [valueDictKeys removeObjectAtIndex:i];
                i--;
                break;//匹配处理完后跳出内循环.
            }
            
        }
    }
    
    [object setValue:tablename forKey:ZG_tableNameKey];
    
    return object;
}

/**
 字典或json格式字符转模型用的处理函数.
 */
+(id)ZG_objectWithClass:(__unsafe_unretained _Nonnull Class)cla value:(id)value{
    if(value == nil)return nil;
    
    NSMutableDictionary* dataDict;
    id object = [cla new];
    if ([value isKindOfClass:[NSString class]]){
        NSAssert([NSJSONSerialization isValidJSONObject:value],@"json数据格式错误!");
        dataDict = [[NSMutableDictionary alloc] initWithDictionary:[self jsonWithString:value] copyItems:YES];
    }else if ([value isKindOfClass:[NSDictionary class]]){
        dataDict = [[NSMutableDictionary alloc] initWithDictionary:value copyItems:YES];
    }else{
        NSAssert(NO,@"数据格式错误!, 只能转换字典或json格式数据.");
    }
    NSDictionary* const objectClaInArr = [ZGDBTool executeSelector:NSSelectorFromString(@"ZG_objectClassInArray") forClass:[object class]];
    NSDictionary* const objectClaForCustom = [ZGDBTool executeSelector:NSSelectorFromString(@"ZG_objectClassForCustom") forClass:[object class]];
    NSDictionary* const ZG_replacedKeyFromPropertyNameDict = [ZGDBTool executeSelector:NSSelectorFromString(@"ZG_replacedKeyFromPropertyName") forClass:[object class]];
    NSArray* const claKeys = [self getClassIvarList:cla Object:nil onlyKey:YES];
    //遍历自定义变量集合信息.
    !objectClaForCustom?:[objectClaForCustom enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull customKey, id  _Nonnull customObj, BOOL * _Nonnull stop) {
        if ([customKey containsString:@"."]){
            NSArray* keyPaths = [customKey componentsSeparatedByString:@"."];
            id value = [dataDict valueForKeyPath:customKey];
            dataDict[keyPaths.lastObject] = value;
            if(![objectClaForCustom.allKeys containsObject:keyPaths.firstObject]){
                [dataDict removeObjectForKey:keyPaths.firstObject];
            }
        }
    }];
    
    //处理要替换的key和属性名.
    if(ZG_replacedKeyFromPropertyNameDict && ZG_replacedKeyFromPropertyNameDict.count){
        [ZG_replacedKeyFromPropertyNameDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if([dataDict.allKeys containsObject:key]){
                dataDict[obj] = dataDict[key];
                [dataDict removeObjectForKey:key];
            }
        }];
    }
    
    [dataDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull dataDictObj, BOOL * _Nonnull stop) {
        for(NSString* claKey in claKeys){
            if ([key isEqualToString:claKey]){
                __block id ArrObject = dataDictObj;
                //遍历自定义变量数组集合信息.
                !objectClaInArr?:[objectClaInArr enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull Arrkey, id  _Nonnull ArrObjCla, BOOL * _Nonnull stop){
                    if([key isEqualToString:Arrkey]){
                        NSMutableArray* ArrObjects = [NSMutableArray array];
                        for(NSDictionary* ArrObj in dataDictObj){
                            id obj = [self ZG_objectWithClass:ArrObjCla value:ArrObj];
                            [ArrObjects addObject:obj];
                        }
                        ArrObject = ArrObjects;
                        *stop = YES;
                    }
                }];
                
                //遍历自定义变量集合信息.
                !objectClaForCustom?:[objectClaForCustom enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull customKey, id  _Nonnull customObj, BOOL * _Nonnull stop) {
                    NSString* tempKey = customKey;
                    if ([customKey containsString:@"."]){
                        tempKey = [customKey componentsSeparatedByString:@"."].lastObject;
                    }
                    
                    if([key isEqualToString:tempKey]){
                        ArrObject = [self ZG_objectWithClass:customObj value:[dataDict valueForKey:tempKey]];
                        *stop = YES;
                    }
                }];
                
                [object setValue:ArrObject forKey:key];
                break;//匹配到了就跳出循环.
            }
        }
    }];
    
    return object;
}

/**
 模型转字典.
 */
+(NSMutableDictionary*)ZG_keyValuesWithObject:(id)object ignoredKeys:(NSArray*)ignoredKeys{
    NSMutableArray<NSString*>* keys = [[NSMutableArray alloc] initWithArray:[self getClassIvarList:[object class] Object:nil onlyKey:YES]];
    if (ignoredKeys) {
        [keys removeObjectsInArray:ignoredKeys];
    }
    NSDictionary* const objectClaInArr = [ZGDBTool executeSelector:NSSelectorFromString(@"ZG_objectClassInArray") forClass:[object class]];
    NSDictionary* const objectClaForCustom = [ZGDBTool executeSelector:NSSelectorFromString(@"ZG_dictForCustomClass") forClass:[object class]];
    NSMutableDictionary* dictM = [NSMutableDictionary dictionary];
    
    [keys enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        __block id value = [object valueForKey:key];
        //遍历自定义变量数组集合信息.
        !objectClaInArr?:[objectClaInArr enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull Arrkey, id  _Nonnull ArrObjCla, BOOL * _Nonnull stop){
            if([key isEqualToString:Arrkey]){
                NSMutableArray* ArrObjects = [NSMutableArray array];
                for(id arrObj in value){
                    id dictObj = [self ZG_keyValuesWithObject:arrObj ignoredKeys:nil];
                    [ArrObjects addObject:dictObj];
                }
                value = ArrObjects;
                *stop = YES;
            }
        }];
        
        //遍历自定义变量集合信息.
        !objectClaForCustom?:[objectClaForCustom enumerateKeysAndObjectsUsingBlock:^(NSString*  _Nonnull customKey, id  _Nonnull customObj, BOOL * _Nonnull stop) {
            if([key isEqualToString:customKey]){
                value = [self ZG_keyValuesWithObject:[object valueForKey:customKey] ignoredKeys:nil];
                *stop = YES;
            }
        }];
        
        //存到集合里.
        !value?:[dictM setValue:value forKey:key];
    }];
    
    
    return dictM;
}

//根据NSDictionary转换从数据库读取回来的数组数据
+(id)valueForArrayRead:(NSDictionary*)dictionary{
    
    NSString* key = dictionary.allKeys.firstObject;
    if ([key isEqualToString:ZGValue]) {
        return dictionary[key];
    }else if ([key isEqualToString:ZGData]){
        return [[NSData alloc] initWithBase64EncodedString:dictionary[key] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }else if([key isEqualToString:ZGSet]){
        return [self arrayFromJsonString:dictionary[key]];
    }else if([key isEqualToString:ZGArray]){
        return [self arrayFromJsonString:dictionary[key]];
    }else if ([key isEqualToString:ZGDictionary]){
        return [self dictionaryFromJsonString:dictionary[key]];
    }else if ([key containsString:ZGModel]){
        NSString* claName = [key componentsSeparatedByString:@"*"].lastObject;
        NSDictionary* valueDict = [self jsonWithString:dictionary[key]];
        id object = [self objectFromJsonStringWithTableName:claName class:NSClassFromString(claName) valueDict:valueDict];
        return object;
    }else{
        NSAssert(NO,@"没有找到匹配的解析类型");
        return nil;
    }
    
}
//json字符串转NSArray
+(NSArray*)arrayFromJsonString:(NSString*)jsonString{
    if(!jsonString || [jsonString isKindOfClass:[NSNull class]])return nil;
    
    if([jsonString containsString:ZGModel] || [jsonString containsString:ZGData]){
        NSMutableArray* arrM = [NSMutableArray array];
        NSArray* array = [self jsonWithString:jsonString];
        for(NSDictionary* dict in array){
            [arrM addObject:[self valueForArrayRead:dict]];
        }
        return arrM;
    }else{
        return [self jsonWithString:jsonString];
    }
}

//根据NSDictionary转换从数据库读取回来的字典数据
+(id)valueForDictionaryRead:(NSDictionary*)dictDest{
    
    NSString* keyDest = dictDest.allKeys.firstObject;
    if([keyDest isEqualToString:ZGValue]){
        return dictDest[keyDest];
    }else if ([keyDest isEqualToString:ZGData]){
        return [[NSData alloc] initWithBase64EncodedString:dictDest[keyDest] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }else if([keyDest isEqualToString:ZGSet]){
        return [self arrayFromJsonString:dictDest[keyDest]];
    }else if([keyDest isEqualToString:ZGArray]){
        return [self arrayFromJsonString:dictDest[keyDest]];
    }else if([keyDest isEqualToString:ZGDictionary]){
        return [self dictionaryFromJsonString:dictDest[keyDest]];
    }else if([keyDest containsString:ZGModel]){
        NSString* claName = [keyDest componentsSeparatedByString:@"*"].lastObject;
        NSDictionary* valueDict = [self jsonWithString:dictDest[keyDest]];
        return [self objectFromJsonStringWithTableName:claName class:NSClassFromString(claName) valueDict:valueDict];
    }else{
        NSAssert(NO,@"没有找到匹配的解析类型");
        return nil;
    }
    
}
//json字符串转NSDictionary
+(NSDictionary*)dictionaryFromJsonString:(NSString*)jsonString{
    if(!jsonString || [jsonString isKindOfClass:[NSNull class]])return nil;
    
    if([jsonString containsString:ZGModel] || [jsonString containsString:ZGData]){
        NSMutableDictionary* dictM = [NSMutableDictionary dictionary];
        NSDictionary* dictSrc = [self jsonWithString:jsonString];
        for(NSString* keySrc in dictSrc.allKeys){
            NSDictionary* dictDest = dictSrc[keySrc];
            dictM[keySrc]= [self valueForDictionaryRead:dictDest];
        }
        return dictM;
    }else{
        return [self jsonWithString:jsonString];
    }
}
//json字符串转NSMapTable
+(NSMapTable*)mapTableFromJsonString:(NSString*)jsonString{
    if(!jsonString || [jsonString isKindOfClass:[NSNull class]])return nil;
    
    NSDictionary* dict = [self jsonWithString:jsonString];
    NSMapTable* mapTable = [NSMapTable new];
    for(NSString* key in dict.allKeys){
        id value = [self valueForDictionaryRead:dict[key]];
        [mapTable setObject:value forKey:key];
    }
    return mapTable;
}
//json字符串转NSHashTable
+(NSHashTable*)hashTableFromJsonString:(NSString*)jsonString{
    if(!jsonString || [jsonString isKindOfClass:[NSNull class]])return nil;
    
    NSArray* arr = [self jsonWithString:jsonString];
    NSHashTable* hashTable = [NSHashTable new];
    for (id obj in arr) {
        id value = [self valueForArrayRead:obj];
        [hashTable addObject:value];
    }
    return hashTable;
}
//json字符串转NSDate
+(NSDate*)dateFromString:(NSString*)jsonString{
    if(!jsonString || [jsonString isKindOfClass:[NSNull class]])return nil;
    
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSDate *date = [formatter dateFromString:jsonString];
    return date;
}
//转换从数据库中读取出来的数据.
+(NSArray*)tansformDataFromSqlDataWithTableName:(NSString*)tableName class:(__unsafe_unretained _Nonnull Class)cla array:(NSArray*)array{
    //如果传入的class为空，则直接以字典的形式返回.
    if(cla == nil){
        return array;
    }
    
    NSMutableArray* arrM = [NSMutableArray array];
    for(NSDictionary* dict in array){
        id object = [ZGDBTool objectFromJsonStringWithTableName:tableName class:cla valueDict:dict];
        [arrM addObject:object];
    }
    return arrM;
}
/**
 判断类是否实现了某个类方法.
 */
+(id)executeSelector:(SEL)selector forClass:(Class)cla{
    id obj = nil;
    if([cla respondsToSelector:selector]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        obj = [cla performSelector:selector];
#pragma clang diagnostic pop
    }
    return obj;
}
/**
 判断对象是否实现了某个方法.
 */
+(id)executeSelector:(SEL)selector forObject:(id)object{
    id obj = nil;
    if([object respondsToSelector:selector]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        obj = [object performSelector:selector];
#pragma clang diagnostic pop
    }
    return obj;
}
/**
 根据对象获取要更新或插入的字典.
 */
+(NSDictionary* _Nonnull)getDictWithObject:(id _Nonnull)object ignoredKeys:(NSArray* const _Nullable)ignoredKeys filtModelInfoType:(ZG_getModelInfoType)filtModelInfoType{
    NSArray<ZGDBModelInfo*>* infos = [ZGDBModelInfo modelInfoWithObject:object];
    NSMutableDictionary* valueDict = [NSMutableDictionary dictionary];
    if (ignoredKeys) {
        for(ZGDBModelInfo* info in infos){
            if(![ignoredKeys containsObject:info.propertyName]){
                valueDict[info.sqlColumnName] = info.sqlColumnValue;
            }
        }
    }else{
        for(ZGDBModelInfo* info in infos){
            valueDict[info.sqlColumnName] = info.sqlColumnValue;
        }
    }
    
    if (filtModelInfoType == ZG_ModelInfoSingleUpdate){//单条更新操作时,移除 创建时间和主键 字段不做更新
        [valueDict removeObjectForKey:ZG_sqlKey(ZG_createTimeKey)];
        //判断是否定义了“联合主键”.
        NSArray* unionPrimaryKeys = [ZGDBTool executeSelector:ZG_unionPrimaryKeysSelector forClass:[object class]];
        NSString* ZG_id = ZG_sqlKey(ZG_primaryKey);
        if(unionPrimaryKeys.count == 0){
            if([valueDict.allKeys containsObject:ZG_id]) {
                [valueDict removeObjectForKey:ZG_id];
            }
        }else{
            if(![valueDict.allKeys containsObject:ZG_id]) {
                valueDict[ZG_id] = @(1);//没有就预备放入
            }
        }
    }else if(filtModelInfoType == ZG_ModelInfoInsert){//插入时要移除主键,不然会出错.
        //判断是否定义了“联合主键”.
        NSArray* unionPrimaryKeys = [ZGDBTool executeSelector:ZG_unionPrimaryKeysSelector forClass:[object class]];
        NSString* ZG_id = ZG_sqlKey(ZG_primaryKey);
        if(unionPrimaryKeys.count == 0){
            if([valueDict.allKeys containsObject:ZG_id]) {
                [valueDict removeObjectForKey:ZG_id];
            }
        }else{
            if(![valueDict.allKeys containsObject:ZG_id]) {
                valueDict[ZG_id] = @(1);//没有就预备放入
            }
        }
    }else if(filtModelInfoType == ZG_ModelInfoArrayUpdate){//批量更新操作时,移除 创建时间 字段不做更新
        [valueDict removeObjectForKey:ZG_sqlKey(ZG_createTimeKey)];
    }else;
    
    return valueDict;
}
/**
 过滤建表的key.
 */
+(NSArray*)ZG_filtCreateKeys:(NSArray*)ZG_createkeys ignoredkeys:(NSArray*)ZG_ignoredkeys{
    NSMutableArray* createKeys = [NSMutableArray arrayWithArray:ZG_createkeys];
    NSMutableArray* ignoredKeys = [NSMutableArray arrayWithArray:ZG_ignoredkeys];
    //判断是否有需要忽略的key集合.
    if (ignoredKeys.count){
        for(__block int i=0;i<createKeys.count;i++){
            if(ignoredKeys.count){
                NSString* createKey = [createKeys[i] componentsSeparatedByString:@"*"][0];
                [ignoredKeys enumerateObjectsUsingBlock:^(id  _Nonnull ignoreKey, NSUInteger idx, BOOL * _Nonnull stop) {
                    if([createKey isEqualToString:ignoreKey]){
                        [createKeys removeObjectAtIndex:i];
                        [ignoredKeys removeObjectAtIndex:idx];
                        i--;
                        *stop = YES;
                    }
                }];
            }else{
                break;
            }
        }
    }
    return createKeys;
}
/**
 如果表格不存在就新建.
 */
+(BOOL)ifNotExistWillCreateTableWithObject:(id)object ignoredKeys:(NSArray* const)ignoredKeys{
    //检查是否建立了跟对象相对应的数据表
    NSString* tableName = [ZGDBTool getTableNameWithObject:object];
    //获取"唯一约束"字段名
    NSArray* uniqueKeys = [ZGDBTool executeSelector:ZG_uniqueKeysSelector forClass:[object class]];
    //获取“联合主键”字段名
    NSArray* unionPrimaryKeys = [ZGDBTool executeSelector:ZG_unionPrimaryKeysSelector forClass:[object class]];
    __block BOOL isExistTable;
    [[ZGMainDB shareManager] isExistWithTableName:tableName complete:^(BOOL isExist) {
        if (!isExist){//如果不存在就新建
            NSArray* createKeys = [self ZG_filtCreateKeys:[ZGDBTool getClassIvarList:[object class] Object:object onlyKey:NO] ignoredkeys:ignoredKeys];
            [[ZGMainDB shareManager] createTableWithTableName:tableName keys:createKeys unionPrimaryKeys:unionPrimaryKeys uniqueKeys:uniqueKeys complete:^(BOOL isSuccess) {
                isExistTable = isSuccess;
            }];
        }
    }];
    
    return isExistTable;
}

/**
 整形判断
 */
+ (BOOL)isPureInt:(NSString *)string{
    NSScanner* scan = [NSScanner scannerWithString:string];
    int val;
    return [scan scanInt:&val] && [scan isAtEnd];
}
/**
 浮点形判断
 */
+ (BOOL)isPureFloat:(NSString *)string{
    NSScanner* scan = [NSScanner scannerWithString:string];
    float val;
    return [scan scanFloat:&val] && [scan isAtEnd];
}

+(BOOL)getBoolWithKey:(NSString*)key{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:key];
}
+(void)setBoolWithKey:(NSString*)key value:(BOOL)value{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:value forKey:key];
    [defaults synchronize];
}
+(NSString*)getStringWithKey:(NSString*)key{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults stringForKey:key];
}
+(void)setStringWithKey:(NSString*)key value:(NSString*)value{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:value forKey:key];
    [defaults synchronize];
}
+(NSInteger)getIntegerWithKey:(NSString*)key{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults integerForKey:key];
}
+(void)setIntegerWithKey:(NSString*)key value:(NSInteger)value{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:value forKey:key];
    [defaults synchronize];
}

@end
