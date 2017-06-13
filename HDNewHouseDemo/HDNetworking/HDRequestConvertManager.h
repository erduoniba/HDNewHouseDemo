//
//  HDRequestManager.h
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/9.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<AFNetworking/AFNetworking.h>)
    #import <AFNetworking/AFNetworking.h>
#else
    #import "AFNetworking.h"
#endif

@class HDRequestManagerConfig;
@class HDError;

/**
 网络请求方法

 - HDRequestMethodGet: GET方法，通常用于请求服务器发送某个资源，服务器返回的数据可能是缓存数据
 - HDRequestMethodHead: HEAD方法与GET方法的行为很类似，但服务器在响应中只返回首部。不会反回实体的主体部分
 - HDRequestMethodPost: POST方法起初是用来向服务器写入数据的，也可以提交表单，也可以请求获取某个资源数据
 - HDRequestMethodPut: 与GET方法从服务器读取文档相反，PUT方法会向服务器写入文档
 - HDRequestMethodPatch: PATCH 用于资源的部分内容的更新
 - HDRequestMethodDelete: DELETE方法所做的事情就是请服务器删除请求URL所指定的资源。
 */
typedef NS_ENUM(NSInteger, HDRequestMethod) {
    HDRequestMethodGet = 0,
    HDRequestMethodHead,
    HDRequestMethodPost,
    HDRequestMethodPut,
    HDRequestMethodPatch,
    HDRequestMethodDelete,
};

typedef void(^HDRequestManagerSuccess)(NSURLSessionDataTask * _Nullable httpbase, id _Nullable responseObject);
typedef void(^HDRequestManagerFailure)(NSURLSessionDataTask * _Nullable httpbase, HDError * _Nullable error);



/**
 网络请求中间转换类，不关心业务，将上层的请求通过该类转发给AFN、ASI等网络库，请求中的一些配置通过configuration来处理
 */
@interface HDRequestConvertManager : NSObject

/**
 单例初始化网络请求，该类作为一个中间转换类来处理网络请求，内部使用AFN处理，当然可以方便切换成其他网络库，
 比如ASI、系统的NSURLSession，而不影响上层的业务，该类也不会加入上层的一些控制代码，
 一些配置通过configuration传入
 @return 网络请求管理类
 */
+ (instancetype _Nullable )sharedInstance;

/**
 *  当前的网络状态
 */
@property (nonatomic, assign) AFNetworkReachabilityStatus networkStatus;


/**
 上层的请求配置，通过该属性传递，保证该类内部不处理上层的逻辑
 */
@property(nonatomic, strong) HDRequestManagerConfig * _Nullable configuration;


/**
 提供给上层请求

 @param method 请求的方法
 @param parameters 请求的参数
 @param URLString 请求的URL地址，不包含baseUrl
 @param configurationHandler 将默认的配置给到外面，外面可能需要特殊处理
 @param success 请求成功
 @param failure 请求失败
 @return 返回该请求的任务管理者，用于取消该次请求(⚠️⚠️，当返回值为nil时，表明并没有进行网络请求，可能是取缓存数据)
 */
- (NSURLSessionDataTask *_Nullable)requestMethod:(HDRequestMethod)method
                                      parameters:(nullable id)parameters
                                       URLString:(NSString *_Nullable)URLString
                            configurationHandler:(void (^_Nullable)(HDRequestManagerConfig * _Nullable configuration))configurationHandler
                                         success:(HDRequestManagerSuccess _Nullable )success
                                         failure:(HDRequestManagerFailure _Nullable )failure;


/**
 取消所有请求
 */
- (void)cancelAllRequest;

@end
