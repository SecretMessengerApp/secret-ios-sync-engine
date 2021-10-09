// 


@import WireTransport;

#import "ZMLastUpdateEventIDTranscoder+Internal.h"
#import "ZMObjectStrategyDirectory.h"
#import "ZMMissingUpdateEventsTranscoder+Internal.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

@interface ZMLastUpdateEventIDTranscoder ()

@property (nonatomic) ZMSingleRequestSync *lastUpdateEventIDSync;
@property (nonatomic, weak) id<ZMObjectStrategyDirectory> directory;
@property (nonatomic) NSUUID *lastUpdateEventID;
@property (nonatomic, weak) SyncStatus *syncStatus;

@end


@implementation ZMLastUpdateEventIDTranscoder

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)applicationStatus
                                  syncStatus:(SyncStatus *)syncStatus
                             objectDirectory:(id<ZMObjectStrategyDirectory>)directory;
{
    self = [super initWithManagedObjectContext:moc applicationStatus:applicationStatus];
    if(self) {
        self.syncStatus = syncStatus;
        self.directory = directory;
        self.lastUpdateEventIDSync = [[ZMSingleRequestSync alloc] initWithSingleRequestTranscoder:self groupQueue:moc];
    }
    return self;
}

- (ZMStrategyConfigurationOption)configuration
{
    return ZMStrategyConfigurationOptionAllowsRequestsDuringSync;
}

- (void)startRequestingLastUpdateEventIDWithoutPersistingIt
{
    [self.lastUpdateEventIDSync resetCompletionState];
    [self.lastUpdateEventIDSync readyForNextRequest];
}

//- (void)persistLastUpdateEventID
//{
//    if(self.lastUpdateEventID != nil) {
//        ZMMissingUpdateEventsTranscoder *noteSync = [self.directory missingUpdateEventsTranscoder];
//        noteSync.lastUpdateEventID = self.lastUpdateEventID;
//    }
//    self.lastUpdateEventID = nil;
//}

- (BOOL)isDownloadingLastUpdateEventID
{
    return self.lastUpdateEventIDSync.status == ZMSingleRequestInProgress;
}

- (SyncPhase)expectedSyncPhase
{
    return SyncPhaseFetchingLastUpdateEventID;
}

- (SyncPhase)isSyncing
{
    return self.syncStatus.currentSyncPhase == self.expectedSyncPhase;
}

- (ZMTransportRequest *)nextRequestIfAllowed
{
    if (self.isSyncing && !self.isDownloadingLastUpdateEventID) {
        [self startRequestingLastUpdateEventIDWithoutPersistingIt];
        return [self.requestGenerators nextRequest];
    }
    
    return nil;
}

- (NSArray *)requestGenerators;
{
    return @[self.lastUpdateEventIDSync];
}

- (NSArray *)contextChangeTrackers
{
    return @[];
}

- (void)processEvents:(NSArray<ZMUpdateEvent *> __unused *)events
           liveEvents:(BOOL __unused)liveEvents
       prefetchResult:(ZMFetchRequestBatchResult __unused *)prefetchResult;
{
    // no op
}

- (ZMTransportRequest *)requestForSingleRequestSync:(ZMSingleRequestSync *)sync
{
    NOT_USED(sync);
    NSURLComponents *components = [NSURLComponents componentsWithString:@"/notifications/last"];
    
    UserClient *selfClient = [ZMUser selfUserInContext:self.managedObjectContext].selfClient;
    if (selfClient.remoteIdentifier != nil) {
        components.queryItems = @[[NSURLQueryItem queryItemWithName:@"client" value:selfClient.remoteIdentifier]];
    }
    
    return [ZMTransportRequest requestGetFromPath:components.string];
}

- (void)didReceiveResponse:(ZMTransportResponse *)response forSingleRequest:(ZMSingleRequestSync *)sync
{
    NOT_USED(sync);
    SyncStatus *status = self.syncStatus;
    
    NSUUID *lastNotificationID = [[response.payload asDictionary] optionalUuidForKey:@"id"];
    
    if (response.HTTPStatus == 404 && status.currentSyncPhase == self.expectedSyncPhase) {
        [status finishCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
    else if (lastNotificationID != nil) {
        self.lastUpdateEventID = lastNotificationID;
        if (status.currentSyncPhase == self.expectedSyncPhase) {
            [status updateLastUpdateEventIDWithEventID:lastNotificationID];
            [status updateLastHugeUpdateEventIDWithEventID:lastNotificationID];
            [status finishCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
        }
    }
    
}

@end
