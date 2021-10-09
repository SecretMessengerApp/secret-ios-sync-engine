// 


#import "ZMUserSession.h"
#import "ZMUserSession+Internal.h"
#import "ZMOperationLoop.h"

@implementation ZMUserSession (Proxy)

- (ZMProxyRequest *)proxiedRequestWithPath:(NSString * __nonnull)path method:(ZMTransportRequestMethod)method type:(ProxiedRequestType)type callback:(void (^__nullable)(NSData * __nullable, NSHTTPURLResponse * __nonnull, NSError * __nullable))callback;
{
    ZMProxyRequest *request = [[ZMProxyRequest alloc] initWithType:type path:path method:method callback:callback];
    
    [self.syncManagedObjectContext performGroupedBlock:^{
        [self.proxiedRequestStatus addRequest:request];
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
    }];
    
    return request;
}

- (void)cancelProxiedRequest:(ZMProxyRequest *)proxyRequest {
    [self.syncManagedObjectContext performGroupedBlock:^{
        [self.proxiedRequestStatus cancelRequest:proxyRequest];
    }];
}

@end
