//
//  GetAddressInfo.m
//  XBAPIBaseManagerDemo
//
//  Created by xiabob on 16/9/5.
//  Copyright © 2016年 xiabob. All rights reserved.
//

#import "GetAddressInfo.h"

@implementation GetAddressInfo

//http://ip.taobao.com/service/getIpInfo.php?ip=202.108.22.5

- (NSString *)urlProtocol {
    return @"http";
}

- (NSString *)urlHostName {
    return @"ip.taobao.com";
}

- (NSString *)urlPath {
    return @"service/getIpInfo.php";
}

- (nullable NSDictionary *)parameters {
    return @{@"ip": @"202.108.22.5"};
}

- (XBAPIRequestMethod)requestMethod {
    return XBAPIRequestMethodGET;
}

- (BOOL)shouldCache {
    return NO;
}

- (BOOL)isResponseJsonData {
    return NO;
}

- (void)parseData:(nonnull id)responseData {
    NSString *responseString = [[NSString alloc]initWithData:responseData
                                                 encoding:NSUTF8StringEncoding];
    NSLog(@"%@", responseString);
}

@end
