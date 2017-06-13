//
//  HDHomeViewModel.m
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/12.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import "HDHomeViewModel.h"

#import "HDRequestManagerConfig.h"

@implementation HDHomeViewModel

- (HDRequestMethod)hdRequestMethodType {
    return HDRequestMethodGet;
}

- (NSString *)hdRequestURL {
    return @"home/page1.json";
}

- (void)hdRequestConfiguration:(HDRequestManagerConfig *)configuration {
    configuration.timeoutInterval = 5.0f;
    configuration.requestPriorityCache = YES;//优先取缓存数据，不在请求网络数据
    configuration.resultCacheDuration = 60; //设置缓存时长为60秒
}

@end
