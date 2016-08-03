//
//  GetAppInfo.m
//  XBAPIBaseManagerDemo
//
//  Created by xiabob on 16/8/3.
//  Copyright © 2016年 xiabob. All rights reserved.
//

#import "GetAppInfo.h"

@implementation GetAppInfo

//414478124 , https://itunes.apple.com/lookup?id=414478124

- (NSString *)requestUrlString {
    return @"https://itunes.apple.com/lookup";
}

- (NSDictionary *)parameters {
    return @{@"id": @"414478124"};
}

- (XBAPIRequestMethod)requestMethod {
    return XBAPIRequestMethodGET;
}

- (void)parseData:(nonnull id)responseData {
    NSLog(@"%@", responseData);
}

- (BOOL)shouldCache {
    return YES;
}



@end
