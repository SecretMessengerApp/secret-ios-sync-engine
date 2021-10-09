// 


@import Foundation;
@import WireRequestStrategy;

@protocol ZMObjectStrategyDirectory;
@class SyncStatus;

@interface ZMLastUpdateEventIDTranscoder : ZMAbstractRequestStrategy <ZMObjectStrategy>

@property (nonatomic, readonly) BOOL isDownloadingLastUpdateEventID;

- (instancetype _Nonnull)initWithManagedObjectContext:(NSManagedObjectContext * _Nonnull)moc applicationStatus:(id<ZMApplicationStatus> _Nullable)applicationStatus NS_UNAVAILABLE;

- (instancetype _Nonnull)initWithManagedObjectContext:(NSManagedObjectContext * _Nonnull)moc
                                    applicationStatus:(id<ZMApplicationStatus> _Nonnull)applicationStatus
                                           syncStatus:(SyncStatus * _Nonnull)syncStatus
                                      objectDirectory:(id<ZMObjectStrategyDirectory> _Nonnull)directory;


- (void)startRequestingLastUpdateEventIDWithoutPersistingIt;
//- (void)persistLastUpdateEventID;

@end
