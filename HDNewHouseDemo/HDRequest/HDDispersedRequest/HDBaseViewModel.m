//
//  HDBaseViewModel.m
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/12.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import "HDBaseViewModel.h"

#import "HDRequestManagerConfig.h"

@interface HDBaseViewModel ()

@property (nonatomic, strong) HDRequestConvertManager *requestConvertManager;
@property (nonatomic, strong) HDRequestManagerConfig *configuration;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;

@end

@implementation HDBaseViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        self.requestConvertManager = [HDRequestConvertManager sharedInstance];
        self.baseURL = @"https://app.youlian365.com/v2.0/";

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

    self.configuration = self.requestConvertManager.configuration;
}

- (void)setBaseURL:(NSString *)baseURL {
    _baseURL = baseURL;
    self.requestConvertManager.configuration.baseURL = baseURL;
}


#pragma mark - HDBaseViewModelProtocol
- (HDRequestMethod)hdRequestMethodType {
    return HDRequestMethodGet;
}

- (NSString *)hdRequestURL {
    NSAssert(1, @"子类需要实现该协议");
    return @"";
}

- (void)hdRequestConfiguration:(HDRequestManagerConfig *)configuration {

}

- (void)start {
    _dataTask = [self.requestConvertManager requestMethod:[self hdRequestMethodType]
                                               parameters:nil
                                                URLString:[self hdRequestURL]
                                     configurationHandler:^(HDRequestManagerConfig * _Nullable configuration) {
                                         [self hdRequestConfiguration:configuration];
                                     } success:^(NSURLSessionDataTask * _Nullable httpbase, id  _Nullable responseObject) {

                                     } failure:^(NSURLSessionDataTask * _Nullable httpbase, HDError * _Nullable error) {
                                         
                                     }];
}

- (void)canncel {
    [_dataTask cancel];
}

@end
