//
//  ViewController.m
//  XBAPIBaseManagerDemo
//
//  Created by xiabob on 16/8/1.
//  Copyright © 2016年 xiabob. All rights reserved.
//

#import "ViewController.h"
#import "GetAppInfo.h"

@interface ViewController ()<XBAPIManagerCallBackDelegate>

@property (nonatomic, strong) GetAppInfo *api;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.api = [[GetAppInfo alloc] initWithDelegate:self];
    self.api.timeout = 6;
    [self.api loadData];
    
//    self.api = [[GetAppInfo alloc] init];
//    self.api.timeout = 6;
//    [self.api loadDataWithType:XBAPIManagerLoadTypeLocal andCallBackBlock:^(XBAPIBaseManager * _Nonnull apiManager) {
//        NSLog(@"CallBackBlock:%@", apiManager.rawResponseString);
//    }];
}

- (void)dealloc {
    NSLog(@"dealloc");
}

#pragma mark - XBAPIManagerCallBackDelegate

- (void)onManagerCallApiSuccess:(XBAPIBaseManager *)manager {
    NSLog(@"onManagerCallApiSuccess");
}

- (void)onManagerCallApiFailed:(XBAPIBaseManager *)manager {
    NSLog(@"onManagerCallApiFailed");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
