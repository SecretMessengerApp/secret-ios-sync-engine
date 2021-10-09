//


#import "ZMUserSession.h"

@interface ZMUserSession (OperationLoop)

@property (nonatomic, readonly) ZMOperationLoop *operationLoop;

@property (nonatomic, readonly) ZMSyncStrategy *syncStrategy;

@end
