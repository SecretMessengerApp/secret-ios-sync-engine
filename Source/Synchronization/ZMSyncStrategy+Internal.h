// 


#import "ZMSyncStrategy.h"
@class ZMGSMCallHandler;

@interface ZMSyncStrategy (Internal)

@property (atomic, readonly) BOOL tornDown;
@property (nonatomic, weak, readonly) NSManagedObjectContext *uiMOC;
@property (nonatomic, readonly) NotificationDispatcher *notificationDispatcher;
@property (nonatomic, readonly) NSArray<ZMObjectSyncStrategy *> *requestStrategies;
@property (nonatomic, readonly) NSArray<ZMObjectSyncStrategy *> *messageRequestStrategies;
@property (nonatomic, readonly) NSArray<id<ZMContextChangeTracker>> *allChangeTrackers;
@property (nonatomic, readonly) NSArray<id<ZMContextChangeTracker>> *messageTrackers;
@end


@interface ZMSyncStrategy (AppBackgroundForeground)

- (void)appDidEnterBackground:(NSNotification *)note;
- (void)appWillEnterForeground:(NSNotification *)note;

@end


@interface ZMSyncStrategy (Testing)

@property (nonatomic) BOOL contextMergingDisabled;

@end


