//
//  HDRequestManager.m
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/9.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import "HDRequestConvertManager.h"

#import "HDRequestManagerConfig.h"
#import "AFNetworkActivityLogger.h"
#import "HDError.h"

#import <PINCache/PINCache.h>

NSString * const HDDNetworkCacheSharedName = @"HDDNetworkCacheSharedName";

@interface HDRequestConvertManager ()

/**
 是AFURLSessionManager的子类，为HTTP的一些请求提供了便利方法，当提供baseURL时，请求只需要给出请求的路径即可
 */
@property (nonatomic, strong) AFHTTPSessionManager *requestManager;

@property (nonatomic, strong) PINCache *cache;


/**
 将HDRequestMethod（NSInteger）类型转换成对应的方法名（NSString）
 */
@property (nonatomic, strong) NSDictionary *methodMap;

@end

@implementation HDRequestConvertManager

+ (instancetype)sharedInstance {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            NSLog(@"Reachability: %@", AFStringFromNetworkReachabilityStatus(status));
            self.networkStatus = status;
        }];
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];

        [[AFNetworkActivityLogger sharedLogger] setLevel:AFLoggerLevelInfo];
        [[AFNetworkActivityLogger sharedLogger] startLogging];

        self.cache = [[PINCache alloc] initWithName:HDDNetworkCacheSharedName];
        self.configuration = [[HDRequestManagerConfig alloc] init];

        _methodMap = @{
                       @"0" : @"GET",
                       @"1" : @"HEAD",
                       @"2" : @"POST",
                       @"3" : @"PUT",
                       @"4" : @"PATCH",
                       @"5" : @"DELETE",
                       };
    }
    return self;
}

#pragma mark - 实例化
- (AFHTTPSessionManager *)requestManager {
    if (!_requestManager) {
        _requestManager = [AFHTTPSessionManager manager] ;
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
        securityPolicy.allowInvalidCertificates = YES;
        securityPolicy.validatesDomainName = NO;
        _requestManager.securityPolicy = securityPolicy;
    }
    return _requestManager;
}


#pragma mark - 接口管理
/**
 提供给上层请求

 @param method 请求的方法
 @param parameters 请求的参数
 @param configurationHandler 将默认的配置给到外面，外面可能需要特殊处理
 @param success 请求成功
 @param failure 请求失败
 @return 返回该请求的任务管理者，用于取消该次请求
 */
- (NSURLSessionDataTask *_Nullable)requestMethod:(HDRequestMethod)method
                                      parameters:(nullable id)parameters
                                       URLString:(NSString *_Nullable)URLString
                            configurationHandler:(void (^_Nullable)(HDRequestManagerConfig * _Nullable configuration))configurationHandler
                                         success:(HDRequestManagerSuccess _Nullable )success
                                         failure:(HDRequestManagerFailure _Nullable )failure {
    //configuration配置
    HDRequestManagerConfig *configuration = [self.configuration copy];
    if (configurationHandler) {
        configurationHandler(configuration);
    }
    self.requestManager.requestSerializer = configuration.requestSerializer;
    self.requestManager.responseSerializer = configuration.responseSerializer;
    if (configuration.builtinHeaders.count > 0) {
        for (NSString *key in configuration.builtinHeaders) {
            [self.requestManager.requestSerializer setValue:configuration.builtinHeaders[key] forHTTPHeaderField:key];
        }
    }

    [self.requestManager.requestSerializer willChangeValueForKey:@"timeoutInterval"];
    if (configuration.timeoutInterval > 0) {
        self.requestManager.requestSerializer.timeoutInterval = configuration.timeoutInterval;
    }
    else {
        self.requestManager.requestSerializer.timeoutInterval = HDRequestTimeoutInterval;
    }
    [self.requestManager.requestSerializer didChangeValueForKey:@"timeoutInterval"];

    NSString *requestUrl = [[NSURL URLWithString:URLString relativeToURL:[NSURL URLWithString:configuration.baseURL]] absoluteString];

    //PINCache缓存取数据
    NSString *cacheKey = [requestUrl stringByAppendingString:[self serializeParams:parameters]];
    if (configuration.requestPriorityCache && method == HDRequestMethodGet) {
        if ([self verifyInvalidCache:cacheKey]) {
            id resposeObject = [self.cache objectForKey:cacheKey];
            if (resposeObject) {
                if (configuration.resposeHandle) {
                    resposeObject = configuration.resposeHandle(nil, resposeObject);
                }
                success(nil, resposeObject);
                return nil;
            }
        }
    }

    //PINCache缓存存数据
    void (^ cacheRespose)(id responseObject) = ^(id responseObject) {
        if (configuration.resultCacheDuration > 0 && method == HDRequestMethodGet) {
            [self setCacheInvalidTimeWithCacheKey:cacheKey resultCacheDuration:configuration.resultCacheDuration];
            [self.cache setObject:responseObject forKey:cacheKey block:^(PINCache * _Nonnull cache, NSString * _Nonnull key, id  _Nullable object) {

            }];
        }
    };


    //接口请求
    NSString *methodKey = [NSString stringWithFormat:@"%d", (int)method];
    NSURLRequest *request = [self.requestManager.requestSerializer requestWithMethod:self.methodMap[methodKey]
                                                                           URLString:requestUrl
                                                                          parameters:parameters
                                                                               error:nil];
    __weak typeof(self) weak_self = self;
    __block NSURLSessionDataTask *dataTask = [self.requestManager
                                              dataTaskWithRequest:request
                                              completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                  __strong typeof(self) strong_self = weak_self;
                                                  if (error) {
                                                      HDError *hdError;
                                                      if (strong_self.networkStatus == AFNetworkReachabilityStatusNotReachable) {
                                                          hdError = [HDError hdErrorNetNotReachable];
                                                      }
                                                      else {
                                                          hdError = [HDError hdErrorHttpError:error];
                                                      }
                                                      failure(dataTask, hdError);
                                                  }
                                                  else {
                                                      if (configuration.resposeHandle) {
                                                          responseObject = configuration.resposeHandle(dataTask, responseObject);
                                                      }
                                                      cacheRespose(responseObject);
                                                      success(dataTask, responseObject);
                                                  }
                                              }];

    [dataTask resume];
    return dataTask;
}


-(NSString *)serializeParams:(NSDictionary *)params {
    NSMutableArray *parts = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id<NSObject> obj, BOOL *stop) {
        NSString *part = [NSString stringWithFormat: @"%@=%@", key, obj];
        [parts addObject: part];
    }];
    if (parts.count > 0) {
        NSString *queryString = [parts componentsJoinedByString:@"&"];
        return queryString ? [NSString stringWithFormat:@"?%@", queryString] : @"";
    }
    return @"";
}

- (BOOL)verifyInvalidCache:(NSString *)cacheKey {
    //获取该次请求失效的时间戳
    NSString *cacheDurationKey = [NSString stringWithFormat:@"%@_cacheDurationKey", cacheKey];
    NSTimeInterval invalidTime = [[self.cache objectForKey:cacheDurationKey] doubleValue];
    NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
    if (invalidTime > nowTime) {
        return YES;
    }
    return NO;
}

- (void)setCacheInvalidTimeWithCacheKey:(NSString *)cacheKey resultCacheDuration:(NSTimeInterval )resultCacheDuration{
    NSString *cacheDurationKey = [NSString stringWithFormat:@"%@_cacheDurationKey", cacheKey];
    NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval invalidTime = nowTime + resultCacheDuration;
    [self.cache setObject:@(invalidTime) forKey:cacheDurationKey];
}

- (void)cancelAllRequest {
    [self.requestManager invalidateSessionCancelingTasks:YES];
}


@end
