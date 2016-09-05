//
//  XBAPIBaseManager.m
//  XBAPIBaseManagerDemo
//
//  Created by xiabob on 16/8/1.
//  Copyright © 2016年 xiabob. All rights reserved.
//

#import "XBAPIBaseManager.h"
#import "AFNetworking.h"


#define kXBLocalUserDefaultsName @"com.xiabob.XBAPIBaseManager.localUserDefaults"
#define kXBDefaultMaxLocalDatasCount 500


@interface XBAPIBaseManager()

@property (nonnull, nonatomic, strong) AFHTTPSessionManager *httpManager;
@property (nullable, nonatomic, weak) NSObject<XBAPIManagerProtocol> *apiManager;

@property (nonatomic, assign) XBAPIManagerLoadType loadType;
@property (nonatomic, assign) XBAPIRequestMethod requestMethod;
@property (nonatomic, copy) NSString *requestUrlString;
@property (nonatomic, copy) NSString *urlProtocol;
@property (nonatomic, copy) NSString *urlHostName;
@property (nonatomic, copy) NSString *urlPath;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, assign) BOOL shouldCache;
@property (nonatomic, assign) BOOL isJsonData;
@property (nonatomic, assign) BOOL isReachable;

@property (nonatomic) dispatch_queue_t parseQueue;
@property (nonatomic, strong) NSMutableDictionary *taskTable;
@property (nonatomic, assign) NSInteger requestId;
@property (nonatomic, strong) NSUserDefaults *localUserDefaults;

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
        
        self.urlProtocol = @"https";
        self.urlHostName = @"";
        self.requestMethod = XBAPIRequestMethodGET;
        self.loadType = XBAPIManagerLoadTypeNetwork;
        self.errorType = XBAPIManagerErrorTypeSuccess;
        self.timeout = 15;//默认超时时间15s
        self.shouldCache = NO;
        self.isJsonData = YES;
        self.isReachable = YES;
        
        [self setProtocolProperties];
    }
    
    return self;
}

- (void)setProtocolProperties {
    if ([self.apiManager respondsToSelector:@selector(urlProtocol)]) {
        self.urlProtocol = self.apiManager.urlProtocol;
    }
    
    if ([self.apiManager respondsToSelector:@selector(urlHostName)]) {
        self.urlHostName = self.apiManager.urlHostName;
    }
    
    if ([self.apiManager respondsToSelector:@selector(requestUrlString)]) {
        self.urlPath = self.apiManager.urlPath;
    }
    //三者构成基本URL数据
    self.requestUrlString = [NSString stringWithFormat:@"%@://%@/%@", self.urlProtocol, self.urlHostName, self.urlPath];
    
    if ([self.apiManager respondsToSelector:@selector(requestMethod)]) {
        self.requestMethod = [self.apiManager requestMethod];
    }
    
    if ([self.apiManager respondsToSelector:@selector(parameters)]) {
        self.parameters = [self.apiManager parameters];
    }
    
    if ([self.apiManager respondsToSelector:@selector(shouldCache)]) {
        self.shouldCache = self.apiManager.shouldCache;
    }
    
    if ([self.apiManager respondsToSelector:@selector(isResponseJsonData)]) {
        self.isJsonData = self.apiManager.isResponseJsonData;
    }
}

- (void)dealloc {
    //in sessionWithConfiguration:delegate:delegateQueue:,If you do specify a delegate, the delegate will be retained until after the delegate has been sent the URLSession:didBecomeInvalidWithError: message.
    //see:AFURLSessionManager init method
    [self.httpManager.session finishTasksAndInvalidate];
    [self cancleAllRequest];
    
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
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

- (NSUserDefaults *)localUserDefaults {
    if (!_localUserDefaults) {
        _localUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:kXBLocalUserDefaultsName];
        if ([[_localUserDefaults dictionaryRepresentation] allKeys].count > kXBDefaultMaxLocalDatasCount) {
            [_localUserDefaults removePersistentDomainForName:kXBLocalUserDefaultsName];
        }
    }
    
    return _localUserDefaults;
}

- (BOOL)isReachable {
    if ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus == AFNetworkReachabilityStatusUnknown) {
        return YES;
    } else {
        return [[AFNetworkReachabilityManager sharedManager] isReachable];
    }
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
    [self excuteHttpRequest];
}

//父类有一个默认的实现，根据自己的需要可以在子类覆盖此方法，实现自己的实现
- (void)loadDataFromLocal {
    if (self.shouldCache) {
        id responseObject = [self getDataFromLocalWithRequestUrl:self.requestUrlString];
        if (responseObject) {
            [self handleResponseData:responseObject];
        } //本地没有缓存数据时，不能当做错误处理
    } else {
        self.errorType = XBAPIManagerErrorTypeLocalLoadError;
        self.errorMsg = @"缓存本地功能未开启";
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
        case XBAPIManagerLoadTypeNetwork:
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
    NSError *requestError;
    NSString *method = [self getRequestMethodString];
    //参数设置最终以dataSource为准
    if ([self.dataSource respondsToSelector:@selector(parametersForApi:)]) {
        self.parameters = [self.dataSource parametersForApi:self];
    }
    
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    NSURLRequest *request = [serializer requestWithMethod:method
                                                URLString:self.requestUrlString
                                               parameters:self.parameters
                                                    error:&requestError];
    //生成请求数据出错，一般是参数错误，配置出错
    if (requestError) {
        self.errorType = XBAPIManagerErrorTypeParametersError;
        self.errorMsg = @"请求参数出错";
        return [self callOnManagerCallApiFailed];
    }
    
    //检查网络连通性
    if (!self.isReachable) {
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
        id result = responseObject;
        if (self.isJsonData) {
            result = [NSJSONSerialization JSONObjectWithData:responseObject
                                                     options:NSJSONReadingAllowFragments
                                                       error:nil];
            if (!result) {return [self callParseDataFailed];}
        }

        if ([self.apiManager respondsToSelector:@selector(parseData:)]) {
            dispatch_async(self.parseQueue, ^{
                [self.apiManager parseData:result];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.errorType == XBAPIManagerErrorTypeSuccess) {
                        [self callOnManagerCallApiSuccess];
                    } else {
                        [self callOnManagerCallApiFailed];
                    }
                });
            });
        } else { //解析工作可能放在了其他地方
            [self callOnManagerCallApiSuccess];
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
    [self.localUserDefaults setObject:responseObject forKey:self.requestUrlString];
    [self.localUserDefaults synchronize];
}

- (id)getDataFromLocalWithRequestUrl:(nonnull NSString *)urlString {
    return [self.localUserDefaults objectForKey:urlString];
}

- (void)removeAllLocalDatas {
    [self.localUserDefaults removePersistentDomainForName:kXBLocalUserDefaultsName];
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
    if ([self.delegate respondsToSelector:@selector(onManagerCallCancled:)]) {
        [self.delegate onManagerCallCancled:self];
    }
    
    if (self.callbackBlcok) {
        self.callbackBlcok(self);
    }
}

@end
