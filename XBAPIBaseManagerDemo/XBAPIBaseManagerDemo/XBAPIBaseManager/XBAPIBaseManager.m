//
//  XBAPIBaseManager.m
//  XBAPIBaseManagerDemo
//
//  Created by xiabob on 16/8/1.
//  Copyright © 2016年 xiabob. All rights reserved.
//

#import "XBAPIBaseManager.h"
#import "AFNetworking.h"



@interface XBAPIBaseManager()

@property (nonnull, nonatomic, strong) AFHTTPSessionManager *httpManager;

@property (nonatomic, assign) XBAPIManagerLoadType loadType;
@property (nonatomic, assign) XBAPIRequestMethod requestMethod;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, copy) NSString *requestUrlString;
@property (nonatomic, assign) BOOL shouldCache;

@property (nonatomic) dispatch_queue_t parseQueue;
@property (nonatomic, strong) NSMutableDictionary *taskTable;
@property (nonatomic, assign) NSInteger requestId;

@property (nonatomic, strong) XBAPIManagerCallBackBlock callbackBlcok;

@end

@implementation XBAPIBaseManager


- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(id<XBAPIManagerCallBackDelegate>)delegate {

    self = [super init];
    if (self) {
        if (![self conformsToProtocol:@protocol(XBAPIManagerProtocol)]) {
            NSString *reason = [NSString stringWithFormat:@"%@ must conform XBAPIManagerProtocol", self];
            NSException *exception = [[NSException alloc] initWithName:@"XBAPIBaseManager init failed"
                                                                reason:reason
                                                              userInfo:nil];
            @throw exception;
        }
        self.apiManager = (id<XBAPIManagerProtocol>)self; //子类必须实现XBAPIManagerProtocol协议的方法
        self.delegate = delegate;
        
        self.requestMethod = XBAPIRequestMethodGET;
        self.loadType = XBAPIManagerLoadTypeNetWork;
        self.errorType = XBAPIManagerErrorTypeSuccess;
        self.timeout = 15;//默认超时时间15s
        self.shouldCache = NO;
    }
    
    return self;
}

- (void)dealloc {
    [self cancleAllRequest];
}

#pragma mark - getter and setter

- (AFHTTPSessionManager *)httpManager {
    if (!_httpManager) {
        _httpManager = [AFHTTPSessionManager manager];
        _httpManager.requestSerializer = [AFHTTPRequestSerializer serializer];
        
        _httpManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [_httpManager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:@"text/html",@"text/html; charset=utf-8",@"image/jpeg",@"image/png",@"application/json",@"text/javascript",@"text/plain",@"multipart/form-data",@"application/x-javascript",nil]];
        
        _httpManager.securityPolicy.allowInvalidCertificates = YES;
        _httpManager.securityPolicy.validatesDomainName = NO;
    }
    
    return _httpManager;
}

- (void)setTimeout:(NSTimeInterval)timeout {
    _timeout = timeout;
    self.httpManager.requestSerializer.timeoutInterval = timeout;
}

- (NSMutableDictionary *)taskTable {
    if (!_taskTable) {
        _taskTable = [[NSMutableDictionary alloc] init];
    }
    
    return _taskTable;
}

- (dispatch_queue_t)parseQueue {
    if (!_parseQueue) {
        _parseQueue = dispatch_queue_create("com.apiManager.parse.queue", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return _parseQueue;
}

#pragma mark - api method cancle

- (void)cancleRequestWithRequestId:(NSInteger)requestId {
    NSURLSessionDataTask *task = [self.taskTable objectForKey:@(requestId)];
    [task cancel];
    [self.taskTable removeObjectForKey:@(requestId)];
}

- (void)cancleCurrentRequest {
    NSURLSessionDataTask *task = [self.taskTable objectForKey:@(self.requestId)];
    [task cancel];
    [self.taskTable removeObjectForKey:@(self.requestId)];
}

- (void)cancleAllRequest {
    for (NSURLSessionDataTask *task in self.taskTable.allValues) {
        [task cancel];
    }
    [self.taskTable removeAllObjects];
}

#pragma mark - api method load data

- (void)loadData {
    if ([self.apiManager respondsToSelector:@selector(requestMethod)]) {
        self.requestMethod = [self.apiManager requestMethod];
    }
    [self excuteHttpRequest];
}

//父类有一个默认的实现，根据自己的需要可以在子类覆盖此方法，实现自己的实现
- (void)loadDataFromLocal {
    self.requestUrlString = self.apiManager.requestUrlString;
    id responseObject = [self getDataFromLocalWithRequestUrl:self.requestUrlString];
    if (responseObject) {
        [self handleResponseData:responseObject];
    } else {
        //可能是本地没有缓存
        self.errorType = XBAPIManagerErrorTypeLocalLoadError;
        self.errorMsg = @"本地没有缓存的数据";
        [self callOnManagerCallApiFailed];
    }
}

- (void)loadDataWithType:(XBAPIManagerLoadType)loadType {
    [self loadDataWithType:loadType andCallBackBlock:nil];
}

- (void)loadDataWithType:(XBAPIManagerLoadType)loadType
        andCallBackBlock:(XBAPIManagerCallBackBlock)block {
    self.callbackBlcok = block;
    self.loadType = loadType;
    switch (self.loadType) {
        case XBAPIManagerLoadTypeNetWork:
            [self loadData];
            break;
            
        case XBAPIManagerLoadTypeLocal:
            [self loadDataFromLocal];
            break;
    }
}

#pragma mark - 具体的load request 工作


//执行具体的网络请求工作,method是对应的请求方式，如GET/POST
- (void)excuteHttpRequest {
    //set default value
    self.requestId = 0;
    if ([self.apiManager respondsToSelector:@selector(shouldCache)]) {
        self.shouldCache = self.apiManager.shouldCache;
    }
    
    NSError *requestError;
    NSString *method = [self getRequestMethodString];
    self.requestUrlString = self.apiManager.requestUrlString;
    NSDictionary *parameters;
    //参数设置最终以dataSource为准
    if ([self.dataSource respondsToSelector:@selector(parametersForApi:)]) {
        parameters = [self.dataSource parametersForApi:self];
    } else {
        parameters = self.apiManager.parameters;
    }
    
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    NSURLRequest *request = [serializer requestWithMethod:method
                                                URLString:self.requestUrlString
                                               parameters:parameters
                                                    error:&requestError];
    //生成请求数据出错，一般是参数错误，配置出错
    if (requestError) {
        self.errorType = XBAPIManagerErrorTypeParametersError;
        self.errorMsg = @"请求参数出错";
        return [self callOnManagerCallApiFailed];
    }
    
    //检查网络连通性
    if ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
        self.errorType = XBAPIManagerErrorTypeNoNetWork;
        self.errorMsg = @"网络未连接";
        return [self callOnManagerCallApiFailed];
    }
    
    __weak typeof (self) weakSelf = self;
    __block NSURLSessionDataTask *apiTask = [self.httpManager dataTaskWithRequest:request
                                                        completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                            //apiTask must use __block,not capture!!
                                                            //因为捕获的时候，apiTask还未初始化完全，值是nil
                                                            [weakSelf.taskTable removeObjectForKey:@(apiTask.taskIdentifier)];
                                                            
                                                            if (error) {
                                                                [weakSelf handleError:error];
                                                            } else {
                                                                if (weakSelf.shouldCache) {
                                                                    [weakSelf saveDataToLocal:responseObject];
                                                                }
                                                                [weakSelf handleResponseData:responseObject];
                                                            }
                                                        }];
    [apiTask resume];
    
    //设置当前请求的唯一id，添加task
    self.requestId = apiTask.taskIdentifier;
    [self.taskTable setObject:apiTask forKey:@(self.requestId)];
}

- (void)handleResponseData:(id)responseObject {
    //get raw string data
    self.rawResponseString = [[NSString alloc]initWithData:responseObject
                                                  encoding:NSUTF8StringEncoding];
    
    @try {
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:responseObject
                                                                 options:NSJSONReadingAllowFragments
                                                                   error:nil];
        if (!jsonDict) {return [self callParseDataFailed];}
        
        if ([self.apiManager respondsToSelector:@selector(parseData:)]) {
            dispatch_async(self.parseQueue, ^{
                [self.apiManager parseData:jsonDict];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self callParseDataSuccess];
                });
            });
        }
        
        
    } @catch (NSException *exception) {
        [self callParseDataFailed];
    }
}

- (void)handleError:(NSError *)error {
    //取消导致的错误单独处理
    if (error.code ==  NSURLErrorCancelled) {
        self.errorType = XBAPIManagerErrorTypeCancle;
        return [self callOnManagerCallCancled];
    }
    
    if (error.code >= 500 && error.code < 600) {
        self.errorType = XBAPIManagerErrorTypeServerError;
        self.errorMsg = error.description;
    } else {
        self.errorType = XBAPIManagerErrorTypeHttpError;
        self.errorMsg = error.description;
    }
    
    [self callOnManagerCallApiFailed];
}

#pragma mark - local cache

- (void)saveDataToLocal:(id)responseObject {
    //这里可能有个问题，那就是保存的时候url地址发生了改变，比如有其他请求发出，不过一般只是参数发生变化，本身的urlString不变
    [[NSUserDefaults standardUserDefaults] setObject:responseObject forKey:self.requestUrlString];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)getDataFromLocalWithRequestUrl:(nonnull NSString *)urlString {
    return [[NSUserDefaults standardUserDefaults] objectForKey:urlString];
}

#pragma mark - util methods

- (NSString *)getRequestMethodString {
    switch (self.requestMethod) {
        case XBAPIRequestMethodGET:
            return @"GET";
            break;
            
        case XBAPIRequestMethodPOST:
            return @"POST";
            break;
    }
}

- (void)callParseDataFailed {
    //XBAPIManagerErrorTypeParseError
    self.errorType = XBAPIManagerErrorTypeParseError;
    self.errorMsg = @"数据解析出错";
    [self callOnManagerCallApiFailed];
}

- (void)callParseDataSuccess {
    self.errorType = XBAPIManagerErrorTypeSuccess;
    [self callOnManagerCallApiSuccess];
}

- (void)callOnManagerCallApiSuccess {
    if ([self.delegate respondsToSelector:@selector(onManagerCallApiSuccess:)]) {
        [self.delegate onManagerCallApiSuccess:self];
    }
    
    if (self.callbackBlcok) {
        self.callbackBlcok(self);
    }
}

- (void)callOnManagerCallApiFailed {
    if ([self.delegate respondsToSelector:@selector(onManagerCallApiFailed:)]) {
        [self.delegate onManagerCallApiFailed:self];
    }
    
    if (self.callbackBlcok) {
        self.callbackBlcok(self);
    }
}

- (void)callOnManagerCallCancled {
    if ([self.delegate respondsToSelector:@selector(callOnManagerCallCancled)]) {
        [self.delegate onManagerCallCancled];
    }
    
    if (self.callbackBlcok) {
        self.callbackBlcok(self);
    }
}

@end
