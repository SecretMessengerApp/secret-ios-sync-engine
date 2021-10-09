// 


@import Foundation;
@import WireRequestStrategy;
@import WireRequestStrategy;

@class NSManagedObjectContext;
@class SyncStatus;

extern NSUInteger const ZMUserTranscoderNumberOfUUIDsPerRequest;

@interface ZMUserTranscoder : ZMAbstractRequestStrategy <ZMObjectStrategy>

- (instancetype _Nonnull)initWithManagedObjectContext:(NSManagedObjectContext * _Nonnull)moc
                                     applicationStatus:(id<ZMApplicationStatus> _Nullable)applicationStatus NS_UNAVAILABLE;

- (instancetype _Nonnull)initWithManagedObjectContext:(NSManagedObjectContext * _Nonnull)moc
                                    applicationStatus:(id<ZMApplicationStatus> _Nullable)applicationStatus
                                           syncStatus:(SyncStatus * _Nullable)syncStatus;

+ (ZMTransportRequest * _Nullable)requestForRemoteIdentifiers:(NSArray * _Nonnull)remoteIdentifiers;

@end
