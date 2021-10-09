// 


@import WireUtilities;
@import WireTransport;
@import WireRequestStrategy;
@import WireDataModel;

#import "ZMMissingHugeUpdateEventsTranscoder+Internal.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>
#import "WireSyncEngineLogs.h"


static NSString * const LastHugeUpdateEventIDStoreKey = @"LastHugeUpdateEventID";
static NSString * const NotificationsKey = @"notifications";
static NSString * const NotificationsPath = @"/notifications/bgps";
static NSString * const StartKey = @"since";

NSUInteger const ZMMissingHugeUpdateEventsTranscoderListPageSize = 500;

@interface ZMMissingHugeUpdateEventsTranscoder ()

@property (nonatomic, readonly, weak) ZMSyncStrategy *syncStrategy;
@property (nonatomic, weak) id<PreviouslyReceivedEventIDsCollection> previouslyReceivedEventIDsCollection;
@property (nonatomic, weak) id <ZMApplication> application;
@property (nonatomic) PushHugeNotificationStatus *pushHugeNotificationStatus;
@property (nonatomic, weak) SyncStatus* syncStatus;
@property (nonatomic, weak) OperationStatus* operationStatus;
@property (nonatomic, weak) id<ClientRegistrationDelegate> clientRegistrationDelegate;
@property (nonatomic) NotificationsTracker *notificationsTracker;

@end


@interface ZMMissingHugeUpdateEventsTranscoder (Pagination) <ZMSimpleListRequestPaginatorSync>
@end


@implementation ZMMissingHugeUpdateEventsTranscoder


- (instancetype)initWithSyncStrategy:(ZMSyncStrategy *)strategy
previouslyReceivedEventIDsCollection:(id<PreviouslyReceivedEventIDsCollection>)eventIDsCollection
                         application:(id <ZMApplication>)application
                   applicationStatus:(ApplicationStatusDirectory *)applicationStatus
{
    self = [super initWithManagedObjectContext:strategy.syncMOC applicationStatus:applicationStatus];
    if(self) {
        _syncStrategy = strategy;
        if (applicationStatus.analytics != nil) {
            self.notificationsTracker = [[NotificationsTracker alloc] initWithAnalytics:applicationStatus.analytics];
        }
        self.application = application;
        self.previouslyReceivedEventIDsCollection = eventIDsCollection;
        self.pushHugeNotificationStatus = applicationStatus.pushHugeNotificationStatus;
        self.syncStatus = applicationStatus.syncStatus;
        self.operationStatus = applicationStatus.operationStatus;
        self.listPaginator = [[ZMSimpleListRequestPaginator alloc] initWithBasePath:NotificationsPath
                                                                           startKey:StartKey
                                                                           pageSize:ZMMissingHugeUpdateEventsTranscoderListPageSize
                                                                managedObjectContext:self.managedObjectContext
                                                                    includeClientID:YES
                                                                         transcoder:self];
    }
    return self;
}

- (ZMStrategyConfigurationOption)configuration
{
    return ZMStrategyConfigurationOptionAllowsRequestsDuringSync
         | ZMStrategyConfigurationOptionAllowsRequestsWhileInBackground
         | ZMStrategyConfigurationOptionAllowsRequestsDuringEventProcessing
         | ZMStrategyConfigurationOptionAllowsRequestsDuringNotificationStreamFetch;
}

- (BOOL)isDownloadingMissingNotifications
{
    return self.listPaginator.hasMoreToFetch;
}

- (BOOL)isFetchingStreamForAPNS
{
    return self.applicationStatus.notificationHugeFetchStatus == BackgroundNotificationFetchStatusInProgress;
}

- (BOOL)isFetchingStreamInBackground
{
    return self.operationStatus.operationState == SyncEngineOperationStateBackgroundFetch;
}

- (NSUUID *)lastUpdateEventID
{
    return self.managedObjectContext.zm_lastHugeNotificationID;
}

- (void)setLastUpdateEventID:(NSUUID *)lastUpdateEventID
{
    self.managedObjectContext.zm_lastHugeNotificationID = lastUpdateEventID;
}

- (void)updateServerTimeDeltaWithTimestamp:(NSString *)timestamp {
    NSDate *serverTime = [NSDate dateWithTransportString:timestamp];
    NSTimeInterval serverTimeDelta = [serverTime timeIntervalSinceNow];
    self.managedObjectContext.serverTimeDelta = serverTimeDelta;
}

+ (NSArray<NSDictionary *> *)eventDictionariesFromPayload:(id<ZMTransportData>)payload
{
    return [payload.asDictionary optionalArrayForKey:@"notifications"].asDictionaries;
}

- (NSUUID *)processUpdateEventsAndReturnLastNotificationIDFromPayload:(id<ZMTransportData>)payload syncStrategy:(ZMSyncStrategy *)syncStrategy
{
    ZMSTimePoint *tp = [ZMSTimePoint timePointWithInterval:10 label:NSStringFromClass(self.class)];
    NSArray *eventsDictionaries = [self.class eventDictionariesFromPayload:payload];
    
    NSMutableArray<ZMUpdateEvent *> *parsedEvents = [NSMutableArray array];
    NSMutableArray<NSUUID *> *eventIds = [NSMutableArray array];
    NSUUID *latestEventId = nil;
    ZMUpdateEventSource source = self.isFetchingStreamForAPNS || self.isFetchingStreamInBackground ? ZMUpdateEventSourcePushNotification : ZMUpdateEventSourceDownload;
    for (NSDictionary *eventDictionary in eventsDictionaries) {
        NSArray *events = [ZMUpdateEvent eventsArrayFromTransportData:eventDictionary source:source];
        
        for (ZMUpdateEvent *event in events) {
            [event appendDebugInformation:@"From missing update events transcoder, processUpdateEventsAndReturnLastNotificationIDFromPayload"];
            [parsedEvents addObject:event];
            [eventIds addObject:event.uuid];
            
            if (!event.isTransient) {
                latestEventId = event.uuid;
            }
        }
    }
    
    ZMLogWithLevelAndTag(ZMLogLevelInfo, ZMTAG_EVENT_PROCESSING, @"Downloaded %lu event(s)", (unsigned long)parsedEvents.count);
    
    [syncStrategy processHugeUpdateEvents:parsedEvents ignoreBuffer:YES];
//    [self.pushHugeNotificationStatus didFetchEventIds:eventIds lastEventId:latestEventId finished:!self.listPaginator.hasMoreToFetch];
    
    [tp warnIfLongerThanInterval];
    return latestEventId;
}

- (void)updateBackgroundFetchResultWithResponse:(ZMTransportResponse *)response {
    UIBackgroundFetchResult result;
    if (response.result == ZMTransportResponseStatusSuccess) {
        if ([self.class eventDictionariesFromPayload:response.payload].count > 0) {
            result = UIBackgroundFetchResultNewData;
        } else {
            result = UIBackgroundFetchResultNoData;
        }
    } else {
        result = UIBackgroundFetchResultFailed;
    }
    
    [self.operationStatus finishBackgroundFetchWithFetchResult:result];
}

- (BOOL)hasLastUpdateEventID
{
    return self.lastUpdateEventID != nil;
}

- (void)startDownloadingMissingNotifications
{
    [self.listPaginator resetFetching];
}

- (NSArray *)contextChangeTrackers
{
    return @[];
}

- (NSArray *)requestGenerators;
{
    return @[self.listPaginator];
}

- (void)processEvents:(NSArray<ZMUpdateEvent *> *)events
           liveEvents:(BOOL)liveEvents
       prefetchResult:(__unused ZMFetchRequestBatchResult *)prefetchResult;
{
    
    for (ZMUpdateEvent *event in events) {
        if (event.uuid != nil && ! event.isTransient && event.isHuge) {
            self.lastUpdateEventID = event.uuid;
        }
    }
}

- (ZMTransportRequest *)nextRequestIfAllowed
{
    /// There are multiple scenarios in which this class will create a new request:
    ///
    /// 1.) We received a push notification and want to fetch the notification stream.
    /// 2.) The OS awoke the application to perform a background fetch (the operation state will indicate this).
    /// 3.) The application came to the foreground and is performing a quick-sync (c.f. `isSyncing`).

    // We want to create a new request if we are either currently fetching the paginated stream
    // or if we have a new notification ID that requires a pingback.
    if (self.isFetchingStreamForAPNS || self.isFetchingStreamInBackground || self.isSyncing) {
        // We only reset the paginator if it is neither in progress nor has more pages to fetch.
        NSLog(@"Huge isFetchingStreamForAPNS: %d  isFetchingStreamInBackground %d  isSyncing: %d",self.isFetchingStreamForAPNS, self.isFetchingStreamInBackground, self.isSyncing);
        
        if (self.listPaginator.status != ZMSingleRequestInProgress && !self.listPaginator.hasMoreToFetch && !self.listPaginator.inProgress) {
            [self.listPaginator resetFetching];
        }

        ZMTransportRequest *request = [self.listPaginator nextRequest];

        if (self.isFetchingStreamForAPNS && nil != request) {
            [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.managedObjectContext block:^(__unused ZMTransportResponse * _Nonnull response) {
            }]];
        }

        return request;
    } else {
        return nil;
    }
}

- (SyncPhase)expectedSyncPhase
{
    return SyncPhaseFetchingHugeMissedEvents;
}

- (BOOL)isSyncing
{
    return self.syncStatus.currentSyncPhase == self.expectedSyncPhase;
}

@end


@implementation ZMMissingHugeUpdateEventsTranscoder (Pagination)

- (NSUUID *)nextUUIDFromResponse:(ZMTransportResponse *)response forListPaginator:(ZMSimpleListRequestPaginator *)paginator
{

    NOT_USED(paginator);
    SyncStatus *syncStatus = self.syncStatus;
    OperationStatus *operationStatus = self.operationStatus;
    
    NSString *timestamp = ((NSString *) response.payload.asDictionary[@"time"]);
    if (timestamp) {
        [self updateServerTimeDeltaWithTimestamp:timestamp];
    }

    NSUUID *latestEventId = [self processUpdateEventsAndReturnLastNotificationIDFromPayload:response.payload syncStrategy:self.syncStrategy];

    if (operationStatus.operationState == SyncEngineOperationStateBackgroundFetch) {
        // This call affects the `isFetchingStreamInBackground` property and should never preceed
        // the call to `processUpdateEventsAndReturnLastNotificationIDFromPayload:syncStrategy`.
        [self updateBackgroundFetchResultWithResponse:response];
    }
    
//    if (latestEventId != nil) {
//        if (response.HTTPStatus == 404 && self.isSyncing) {
            // If we fail during quick sync we need to re-enter slow sync and should not store the lastUpdateEventID until after the slowSync has been completed
            // Otherwise, if the device crashes or is restarted during slow sync, we lose the information that we need to perform a slow sync
//            [syncStatus updateLastHugeUpdateEventIDWithEventID:latestEventId];
            // TODO Sabine: What happens when we receive a 404 when we are fetching the notification for a push notification? In theory we would have to enter slow sync as well or at least not store the lastUpdateEventID until the next proper sync in the foreground
//        }
//    }
    
    if (!self.listPaginator.hasMoreToFetch) {
        [self.previouslyReceivedEventIDsCollection discardListOfAlreadyReceivedHugePushEventIDs];
    }
        
    if (response.result == ZMTransportResponseStatusPermanentError && self.isSyncing){
        [syncStatus failCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
    
    if (!self.listPaginator.hasMoreToFetch && self.isSyncing) {
        
        // The fetch of the notification stream was initiated after the push channel was established
        // so we must restart the fetching to be sure that we haven't missed any notifications.
        if (syncStatus.pushChannelEstablishedDate.timeIntervalSinceReferenceDate < self.listPaginator.lastResetFetchDate.timeIntervalSinceReferenceDate) {
            [syncStatus finishCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
        }
    }
    
    return self.lastUpdateEventID;
}

- (NSUUID *)startUUID
{
    return self.lastUpdateEventID;
}

- (BOOL)shouldParseErrorForResponse:(ZMTransportResponse *)response
{
    [self.pushHugeNotificationStatus didFailToFetchEvents];
    
    if (response.HTTPStatus == 404) {
        return YES;
    }
    
    return NO;
}

@end
