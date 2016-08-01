//
//  XBAPIBaseManager.h
//  XBAPIBaseManagerDemo
//
//  Created by xiabob on 16/8/1.
//  Copyright © 2016年 xiabob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"
@class XBAPIBaseManager;

#pragma mark - Enum

typedef NS_ENUM(NSUInteger, XBAPIManagerErrorType) {
    /** 请求成功，返回数据正确  */
    XBAPIManagerErrorTypeSuccess = 0,
    
    /** 请求成功，返回数据正确  */
    XBAPIManagerErrorTypeParameters,
};


#pragma mark - XBAPIManagerDataSource
@protocol XBAPIManagerDataSource <NSObject>

/**
 *  配置接口需要的参数
 *
 *  @param manager
 *
 *  @return 参数
 */
- (NSDictionary *)paramsForApi:(XBAPIBaseManager *)manager;

@end

#pragma mark - XBAPIManagerCallBackDelegate
@protocol XBAPIManagerCallBackDelegate <NSObject>

/**
 *  成功调用接口，并成功返回数据
 *
 *  @param manager
 */
- (void)onManagerCallApiSuccess:(XBAPIBaseManager *)manager;

/**
 *  调用接口失败
 *
 *  @param manager
 */
- (void)onManagerCallApiFailed:(XBAPIBaseManager *)manager;

@end


#pragma mark - XBAPIBaseManager
@interface XBAPIBaseManager : NSObject

@property (nonatomic, weak) id<XBAPIManagerCallBackDelegate> delegate;
@property (nonatomic, weak) id<XBAPIManagerDataSource> dataSource;



@end
