//
//  XBAPIBaseManager.h
//  XBAPIBaseManagerDemo
//
//  Created by xiabob on 16/8/1.
//  Copyright © 2016年 xiabob. All rights reserved.
//

#import <Foundation/Foundation.h>
@class XBAPIBaseManager;

#pragma mark - Enum

/** 调用接口返回的错误码 */
typedef NS_ENUM(NSUInteger, XBAPIManagerErrorType) {
    /** 请求成功，返回数据正确 */
    XBAPIManagerErrorTypeSuccess = 0,
    
    /** 请求的参数错误 */
    XBAPIManagerErrorTypeParametersError,
    
    /** 加载本地缓存数据时出错 */
    XBAPIManagerErrorTypeLocalLoadError,
    
    /** 网络请求成功，返回出错 */
    XBAPIManagerErrorTypeHttpError,
    
    /** 解析返回的数据出错 */
    XBAPIManagerErrorTypeParseError,
    
    /** 请求取消 */
    XBAPIManagerErrorTypeCancle,
    
    /** 请求超时 */
    XBAPIManagerErrorTypeTimeout,
    
    /** 没有网络 */
    XBAPIManagerErrorTypeNoNetWork,
    
    /** 服务器异常 */
    XBAPIManagerErrorTypeServerError,
};

/** 调用接口需要发出的请求方式，常见的如：GET、POST */
typedef NS_ENUM(NSUInteger, XBAPIRequestMethod) {
    /** GET请求 */
    XBAPIRequestMethodGET,
    
    /** POST请求 */
    XBAPIRequestMethodPOST,
};

/** 获取接口数据的方式，从网络了获取、从本地加载…… */
typedef NS_ENUM(NSUInteger, XBAPIManagerLoadType) {
    /** 从网络获取 */
    XBAPIManagerLoadTypeNetWork,
    
    /** 从本地获取 */
    XBAPIManagerLoadTypeLocal,
};

typedef void (^XBAPIManagerCallBackBlock)(XBAPIBaseManager * _Nonnull apiManager);

#pragma mark - XBAPIManagerDataSource
@protocol XBAPIManagerDataSource <NSObject>

/**
 *  配置接口需要的参数，正常情况下XBAPIManager的子类中已经配置了请求参数，但是如果这里设置了参数，最终以这里的值为准.
 *
 *  @param manager
 *
 *  @return 参数
 */
- (nullable NSDictionary *)parametersForApi:(nonnull XBAPIBaseManager *)manager;

@end

#pragma mark - XBAPIManagerCallBackDelegate
@protocol XBAPIManagerCallBackDelegate <NSObject>

/**
 *  成功调用接口，并成功返回数据
 *
 *  @param manager
 */
- (void)onManagerCallApiSuccess:(nonnull XBAPIBaseManager *)manager;

/**
 *  调用接口失败
 *
 *  @param manager
 */
- (void)onManagerCallApiFailed:(nonnull XBAPIBaseManager *)manager;


@optional

/**
 *  取消网络请求的回调
 */
- (void)onManagerCallCancled:(nonnull XBAPIBaseManager *)manager;

@end

#pragma mark - XBAPIManagerProtocol
@protocol XBAPIManagerProtocol <NSObject>

- (nonnull NSString *)requestUrlString;
- (XBAPIRequestMethod)requestMethod;

@optional
- (nullable NSDictionary *)parameters; ///< 配置接口需要的参数
- (BOOL)shouldCache; ///< 需要本地缓存数据吗？
- (void)parseData:(nonnull id)responseData; ///< 注意该方法本身处在子线程环境中:具体的解析工作要放在子类中进行，并且这个解析工作可以延后至onManagerCallApiSuccess里面进行


@end


#pragma mark - XBAPIBaseManager
@interface XBAPIBaseManager : NSObject

@property (nullable, nonatomic, weak) id<XBAPIManagerCallBackDelegate> delegate;
@property (nullable, nonatomic, weak) id<XBAPIManagerDataSource> dataSource;

//返回的数据
@property (nonatomic, assign) XBAPIManagerErrorType errorType; ///< 错误类型
@property (nullable, nonatomic, copy) NSString *errorMsg; ///< 具体的错误信息
@property (nullable, nonatomic, strong) NSString *rawResponseString; ///< 返回的原始字符串数据
@property (nullable, nonatomic, strong) id contentData; ///< 解析后的数据，可以是nil，一般是子类自己添加新的属性

//其他属性
@property (nonnull ,nonatomic, readonly, copy) NSString *requestUrlString;
@property (nonatomic, assign) NSTimeInterval timeout; ///< 每个接口可以单独设置超时时间

//api method

- (nonnull instancetype)initWithDelegate:(nullable id<XBAPIManagerCallBackDelegate>)delegate;

/** 网络请求接口数据 */
- (void)loadData;

/** 请求本地缓存数据 */
- (void)loadDataFromLocal; 

- (void)loadDataWithType:(XBAPIManagerLoadType)loadType;
- (void)loadDataWithType:(XBAPIManagerLoadType)loadType
        andCallBackBlock:(nullable XBAPIManagerCallBackBlock)block;

- (void)cancleRequestWithRequestId:(NSInteger)requestId;
- (void)cancleCurrentRequest;
- (void)cancleAllRequest;

@end
