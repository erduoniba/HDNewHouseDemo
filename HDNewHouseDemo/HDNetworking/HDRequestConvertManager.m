//
//  HDRequestManager.m
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/9.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import "HDRequestConvertManager.h"

#import "HDRequestManagerConfig.h"
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

/**
 设置网络请求的log等级

 @param loggerLevel log等级，当网络请求失败时，无论是哪种等级都会打印error信息，当网络成功时，
 AFLoggerLevelInfo：打印请求的code码、请求的url和本次请求耗时；
 AFLoggerLevelDebug/AFLoggerLevelWarn/AFLoggerLevelError：打印请求的code码、请求的url、本次请求耗时、header信息及返回数据；
 */
- (void)setLoggerLevel:(AFHTTPRequestLoggerLevel)loggerLevel {
    [[AFNetworkActivityLogger sharedLogger] setLevel:loggerLevel];
}

#pragma mark - 接口管理
/**
 提供给上层请求

 @param method 请求的方法
 @param URLString 请求的URL地址，不包含baseUrl
 @param parameters 请求的参数
 @param configurationHandler 将默认的配置给到外面，外面可能需要特殊处理，可以修改baseUrl等信息
 @param success 请求成功
 @param failure 请求失败
 @return 返回该请求的任务管理者，用于取消该次请求
 */
- (NSURLSessionDataTask *_Nullable)requestMethod:(HDRequestMethod)method
                                       URLString:(NSString *_Nullable)URLString
                                      parameters:(NSDictionary *_Nullable)parameters
                            configurationHandler:(void (^_Nullable)(HDRequestManagerConfig * _Nullable configuration))configurationHandler
                                         success:(HDRequestManagerSuccess _Nullable )success
                                         failure:(HDRequestManagerFailure _Nullable )failure {
    HDRequestManagerConfig *configuration = [self disposeConfiguration:configurationHandler];
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

/**
 上传资源方法

 @param URLString URLString 请求的URL地址，不包含baseUrl
 @param parameters 请求参数
 @param block 将要上传的资源回调
 @param configurationHandler 将默认的配置给到外面，外面可能需要特殊处理，可以修改baseUrl等信息
 @param progress 上传资源进度
 @param success 请求成功
 @param failure 请求失败
 @return 返回该请求的任务管理者，用于取消该次请求(⚠️⚠️，当返回值为nil时，表明并没有进行网络请求，可能是取缓存数据)
 */
- (NSURLSessionTask *_Nullable)uploadWithURLString:(NSString *_Nullable)URLString
                                        parameters:(NSDictionary *_Nullable)parameters
                         constructingBodyWithBlock:(void (^_Nullable)(id <AFMultipartFormData> _Nullable formData))block
                              configurationHandler:(void (^_Nullable)(HDRequestManagerConfig * _Nullable configuration))configurationHandler
                                          progress:(HDRequestManagerProgress _Nullable)progress
                                           success:(HDRequestManagerSuccess _Nullable )success
                                           failure:(HDRequestManagerFailure _Nullable )failure {
    HDRequestManagerConfig *configuration = [self disposeConfiguration:configurationHandler];
    NSString *requestUrl = [[NSURL URLWithString:URLString relativeToURL:[NSURL URLWithString:configuration.baseURL]] absoluteString];
    __weak typeof(self) weak_self = self;
    NSURLSessionDataTask *dataTask = [self.requestManager POST:requestUrl
                                                    parameters:parameters
                                     constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                                         block(formData);
                                     } progress:^(NSProgress * _Nonnull uploadProgress) {
                                         progress(uploadProgress);
                                     } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                                         success(task, responseObject);
                                     } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                         __strong typeof(self) strong_self = weak_self;
                                         HDError *hdError;
                                         if (strong_self.networkStatus == AFNetworkReachabilityStatusNotReachable) {
                                             hdError = [HDError hdErrorNetNotReachable];
                                         }
                                         else {
                                             hdError = [HDError hdErrorHttpError:error];
                                         }
                                         failure(task, hdError);
                                     }];
    [dataTask resume];
    return dataTask;
}

/**
 下载资源方法

 @param URLString URLString 请求的URL地址，不包含baseUrl
 @param configurationHandler 将默认的配置给到外面，外面可能需要特殊处理，可以修改baseUrl等信息
 @param progress 上传资源进度
 @param success 请求成功
 @param failure 请求失败
 @return 返回该请求的任务管理者，用于取消该次请求
 */
- (NSURLSessionTask *_Nullable)downloadWithURLString:(NSString *_Nullable)URLString
                                configurationHandler:(void (^_Nullable)(HDRequestManagerConfig * _Nullable configuration))configurationHandler
                                            progress:(HDRequestManagerProgress _Nullable)progress
                                             success:(HDRequestManagerSuccess _Nullable )success
                                             failure:(HDRequestManagerFailure _Nullable )failure {
    HDRequestManagerConfig *configuration = [self disposeConfiguration:configurationHandler];
    NSString *requestUrl = [[NSURL URLWithString:URLString relativeToURL:[NSURL URLWithString:configuration.baseURL]] absoluteString];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    __weak typeof(self) weak_self = self;
    __block NSURLSessionTask *dataTask = [self.requestManager downloadTaskWithRequest:request
                                                                                 progress:^(NSProgress * _Nonnull downloadProgress) {
                                                                                     progress(downloadProgress);
                                                                                 } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                                                                     NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
                                                                                     return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
                                                                                 } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
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
                                                                                         if (self.configuration.resposeHandle) {
                                                                                             filePath = self.configuration.resposeHandle(dataTask, filePath);
                                                                                         }
                                                                                         success(dataTask, filePath);
                                                                                     }
                                                                                 }];
    [dataTask resume];
    return dataTask;
}


- (HDRequestManagerConfig *)disposeConfiguration:(void (^_Nullable)(HDRequestManagerConfig * _Nullable configuration))configurationHandler {
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
    return configuration;
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
