//
//  HDRequestManager.h
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/12.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HDRequestConvertManager.h"

/**
 集中式的API处理，项目中所有的接口都在此类集中处理，方便接口管理及统一配置
 */
@interface HDRequestManager : NSObject

+ (instancetype _Nullable )sharedInstance;

@property (nonatomic, strong) NSString * _Nullable baseURL;

#pragma mark - 具体接口名
- (void)homePageSuccess:(HDRequestManagerSuccess _Nullable )success
                failure:(HDRequestManagerSuccess _Nullable )failure;

@end
