//
//  ViewController.m
//  HDNewHouseDemo
//
//  Created by denglibing on 2017/6/8.
//  Copyright © 2017年 denglibing. All rights reserved.
//

#import "ViewController.h"

#import "HDRequestManager.h"

#import "HDHomeViewModel.h"

@interface ViewController ()

@property (nonatomic, strong) NSArray	*dataArr;

@property (nonatomic, strong) HDRequestManager *requestManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.title = NSStringFromClass(self.class);

    _dataArr = @[@"HDPYPhotoBrowserVC", @"HDTZImagePickerVC", @"HDBaseProjectVC", @"HDPKShortVideoVC", @"HDFTIndicatorVC", @"HDSDCycleScrollViewVC", @"HDIQKeyboardVC", @"HDLeanCloudChatVC"];

    
}

- (HDRequestManager *)requestManager {
    if (!_requestManager) {
        _requestManager = [HDRequestManager sharedInstance];
        [_requestManager setBaseURL:@"https://app.youlian365.com/v2.0/"];
    }
    return _requestManager;
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _dataArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = _dataArr[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.row % 2 == 0) {
        [self.requestManager homePageSuccess:^(NSURLSessionDataTask * _Nullable httpbase, id  _Nullable responseObject) {
            //NSLog(@"responseObject : %@", responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable httpbase, id  _Nullable responseObject) {

        }];
    }
    else {
        [[HDHomeViewModel new] start];
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
