// 


@import WireRequestStrategy;

@class NSManagedObjectContext;
@class NSOperationQueue;
@class ZMUpstreamModifiedObjectSync;
@class ZMClientRegistrationStatus;
@class ApplicationStatusDirectory;
@class SyncStatus;

@interface ZMSelfStrategy : ZMAbstractRequestStrategy <ZMContextChangeTrackerSource, TearDownCapable>

@property (nonatomic, readonly) BOOL isSelfUserComplete;

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)applicationStatus NS_UNAVAILABLE;

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)appplicationStatus
                    clientRegistrationStatus:(ZMClientRegistrationStatus *)clientRegistrationStatus
                                  syncStatus:(SyncStatus *)syncStatus;

- (void)tearDown;

@end


@interface ZMSelfStrategy (ContextChangeTracker) <ZMContextChangeTracker>
@end


