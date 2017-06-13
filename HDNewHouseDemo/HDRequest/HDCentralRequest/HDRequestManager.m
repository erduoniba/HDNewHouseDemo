//
//  HDRequestManager.m
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/12.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import "HDRequestManager.h"

#import "HDRequestManagerConfig.h"

NSString * const YYBRequestDataTag = @"data";

@interface HDRequestManager ()

@property (nonatomic, strong) HDRequestConvertManager *requestConvertManager;

@end

@implementation HDRequestManager

#pragma mark - 初始化管理
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
        self.requestConvertManager = [HDRequestConvertManager sharedInstance];

        [self initialConfig];
    }
    return self;
}

- (void)initialConfig {
    //通过configuration来设置请求头
    NSMutableDictionary *builtinHeaders = [NSMutableDictionary dictionary];
    builtinHeaders[@"appkey"] = @"GUemVGgSqsWYmeJY";
    builtinHeaders[@"state"] = @"00";
    builtinHeaders[@"Content-Type"] = @"application/json";
    self.requestConvertManager.configuration.builtinHeaders = builtinHeaders;

    //通过configuration来统一处理输出的数据，比如对token失效处理、对需要重新登录拦截
    self.requestConvertManager.configuration.resposeHandle = ^id (NSURLSessionDataTask *dataTask, id responseObject) {
        return responseObject;
    };
}

- (void)setBaseURL:(NSString *)baseURL {
    _baseURL = baseURL;
    self.requestConvertManager.configuration.baseURL = baseURL;
}

- (id)getResultObject:(NSDictionary *)responseObject{
    if ([responseObject isKindOfClass:[NSDictionary class]]) {
        id data = responseObject[YYBRequestDataTag];
        if ([data isKindOfClass:NSNull.class]) {
            return nil;
        }
        return data;
    }
    return nil;
}

#pragma mark - 具体接口
- (void)homePageSuccess:(HDRequestManagerSuccess _Nullable )success
                failure:(HDRequestManagerSuccess _Nullable )failure {
    NSString *url = [NSString stringWithFormat:@"home/page1.json"];
    [self.requestConvertManager requestMethod:HDRequestMethodPost
                                   parameters:@{@"xx" : @"yy"}
                                    URLString:url
                         configurationHandler:^(HDRequestManagerConfig * _Nullable configuration) {
                             configuration.resultCacheDuration = 100000; //设置缓存时长为100000秒
                             configuration.requestPriorityCache = YES; //优先取缓存数据，不在请求网络数据
                         } success:^(NSURLSessionDataTask * _Nullable dataTask, id  _Nullable responseObject) {
                             success(dataTask, responseObject);
                         } failure:^(NSURLSessionDataTask * _Nullable dataTask, HDError * _Nullable error) {
                             failure(dataTask, error);
                         }];
}


@end
