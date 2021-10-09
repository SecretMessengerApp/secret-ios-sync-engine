// 



#import "ZMOperationLoop.h"

@class APSSignalingKeysStore;
@class ZMSyncStrategy;
@class PushNotificationStatus;
@class PushHugeNotificationStatus;
@class ZMSyncStrategy;
@class CallEventStatus;

// Required by OperationLoop+Background.h
@interface ZMOperationLoop ()

@property (nonatomic) APSSignalingKeysStore *apsSignalKeyStore;
@property (nonatomic) ZMSyncStrategy *syncStrategy;
@property (nonatomic, weak) NSManagedObjectContext *syncMOC;
@property (nonatomic, weak) NSManagedObjectContext *msgMOC;
@property (nonatomic, readonly) PushNotificationStatus *pushNotificationStatus;
@property (nonatomic, readonly) PushHugeNotificationStatus *pushHugeNotificationStatus;
@property (nonatomic, readonly) CallEventStatus *callEventStatus;
@end
