// 


@import CoreData;
@import Foundation;
@import WireRequestStrategy;

@class SyncStatus;

@interface ZMConnectionTranscoder : ZMAbstractRequestStrategy <ZMObjectStrategy>

- (instancetype _Nonnull )initWithManagedObjectContext:(NSManagedObjectContext * _Nullable)moc applicationStatus:(id<ZMApplicationStatus> _Nullable)applicationStatus NS_UNAVAILABLE;

- (instancetype _Nonnull )initWithManagedObjectContext:(NSManagedObjectContext *_Nullable)moc applicationStatus:(id<ZMApplicationStatus> _Nullable)applicationStatus syncStatus:(SyncStatus * _Nullable)syncStatus;

@end
