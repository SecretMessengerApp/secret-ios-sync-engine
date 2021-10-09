// 


@import UIKit;
@import WireImages;
@import WireUtilities;
@import WireTransport;
@import WireDataModel;
@import WireRequestStrategy;

#import "ZMSyncStrategy+Internal.h"
#import "ZMSyncStrategy+ManagedObjectChanges.h"
#import "ZMUserSession+Internal.h"
#import "ZMConnectionTranscoder.h"
#import "ZMUserTranscoder.h"
#import "ZMSelfStrategy.h"
#import "ZMConversationTranscoder.h"
#import "ZMAuthenticationStatus.h"
#import "ZMMissingUpdateEventsTranscoder.h"
#import "ZMLastUpdateEventIDTranscoder.h"
#import "WireSyncEngineLogs.h"
#import "ZMClientRegistrationStatus.h"
#import "ZMMissingHugeUpdateEventsTranscoder.h"
#import "ZMHotFix.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

@interface ZMSyncStrategy ()

@property (nonatomic) BOOL didFetchObjects;
@property (nonatomic) BOOL didFetchMessageObjects;
@property (nonatomic) NSManagedObjectContext *syncMOC;
@property (nonatomic) NSManagedObjectContext *msgMOC;
@property (nonatomic, weak) NSManagedObjectContext *uiMOC;

@property (nonatomic) id<ZMApplication> application;

@property (nonatomic) ZMConnectionTranscoder *connectionTranscoder;
@property (nonatomic) ZMUserTranscoder *userTranscoder;
@property (nonatomic) ZMSelfStrategy *selfStrategy;
@property (nonatomic) ZMConversationTranscoder *conversationTranscoder;
@property (nonatomic) ClientMessageTranscoder *clientMessageTranscoder;
@property (nonatomic) ZMMissingUpdateEventsTranscoder *missingUpdateEventsTranscoder;
@property (nonatomic) ZMMissingHugeUpdateEventsTranscoder *missingHugeUpdateEventsTranscoder;
@property (nonatomic) ZMLastUpdateEventIDTranscoder *lastUpdateEventIDTranscoder;
@property (nonatomic) LinkPreviewAssetUploadRequestStrategy *linkPreviewAssetUploadRequestStrategy;
@property (nonatomic) ImageV2DownloadRequestStrategy *imageV2DownloadRequestStrategy;

@property (nonatomic) ZMUpdateEventsBuffer *eventsBuffer;
@property (nonatomic) ZMUpdateEventsBuffer *hugeEventsBuffer;
@property (nonatomic) ZMChangeTrackerBootstrap *changeTrackerBootStrap;
@property (nonatomic) ZMMessageChangeTrackerBootstrap *messageChangeTrackerBootStrap;
@property (nonatomic) ConversationStatusStrategy *conversationStatusSync;
@property (nonatomic) UserClientRequestStrategy *userClientRequestStrategy;
@property (nonatomic) UserDisableSendMsgStatusStrategy *userDisableSendMsgStrategy;
@property (nonatomic) FetchingClientRequestStrategy *fetchingClientRequestStrategy;
@property (nonatomic) MissingClientsRequestStrategy *missingClientsRequestStrategy;
@property (nonatomic) LinkPreviewAssetDownloadRequestStrategy *linkPreviewAssetDownloadRequestStrategy;
@property (nonatomic) PushTokenStrategy *pushTokenStrategy;
@property (nonatomic) ApnsPushTokenStrategy *apnsPushTokenStrategy;
@property (nonatomic) SearchUserImageStrategy *searchUserImageStrategy;

@property (nonatomic, readwrite) CallingRequestStrategy *callingRequestStrategy;

@property (nonatomic) NSManagedObjectContext *eventMOC;
@property (nonatomic) EventDecoder *eventDecoder;
@property (nonatomic) HugeEventDecoder *hugeEventDecoder;
@property (nonatomic, weak) LocalNotificationDispatcher *localNotificationDispatcher;

@property (nonatomic, weak) ApplicationStatusDirectory *applicationStatusDirectory;
@property (nonatomic) ApplicationStatusDirectory *applicationMsgStatusDirectory;
@property (nonatomic) NSArray *allChangeTrackers;
@property (nonatomic) NSArray *messageTrackers;

@property (nonatomic) NSArray<ZMObjectSyncStrategy *> *requestStrategies;
@property (nonatomic) NSArray<ZMObjectSyncStrategy *> *messageRequestStrategies;
@property (nonatomic) NSArray<id<ZMEventConsumer>> *eventConsumers;

@property (atomic) BOOL tornDown;
@property (nonatomic) BOOL contextMergingDisabled;

@property (nonatomic) ZMHotFix *hotFix;
@property (nonatomic) NotificationDispatcher *notificationDispatcher;

@property (nonatomic) NSCache<NSString *, NSString *> *evevdHugeIdCaches;

@end


@interface ZMSyncStrategy (Registration) <ZMClientRegistrationStatusDelegate>
@end

@interface LocalNotificationDispatcher (Push) <PushMessageHandler>
@end

@interface BackgroundAPNSConfirmationStatus (Protocol) <DeliveryConfirmationDelegate>
@end

@interface ZMClientRegistrationStatus (Protocol) <ClientRegistrationDelegate>
@end


@implementation ZMSyncStrategy

ZM_EMPTY_ASSERTING_INIT()


- (instancetype)initWithStoreProvider:(id<LocalStoreProviderProtocol>)storeProvider
                        cookieStorage:(ZMPersistentCookieStorage *)cookieStorage
                          flowManager:(id<FlowManagerType>)flowManager
         localNotificationsDispatcher:(LocalNotificationDispatcher *)localNotificationsDispatcher
              notificationsDispatcher:(NotificationDispatcher *)notificationsDispatcher
           applicationStatusDirectory:(ApplicationStatusDirectory *)applicationStatusDirectory
           msgApplicationStatusDirectory:(ApplicationStatusDirectory *)msgApplicationStatusDirectory
                          application:(id<ZMApplication>)application
{
    self = [super init];
    if (self) {
        self.notificationDispatcher = notificationsDispatcher;
        self.application = application;
        self.localNotificationDispatcher = localNotificationsDispatcher;
        self.syncMOC = storeProvider.contextDirectory.syncContext;
        self.uiMOC = storeProvider.contextDirectory.uiContext;
        self.msgMOC = storeProvider.contextDirectory.msgContext;
        
        self.hotFix = [[ZMHotFix alloc] initWithSyncMOC:self.syncMOC];
        self.eventProcessingTracker = [[EventProcessingTracker alloc] init];
        
        self.eventMOC = [NSManagedObjectContext createEventContextWithSharedContainerURL:storeProvider.applicationContainer userIdentifier:storeProvider.userIdentifier];
        [self.eventMOC addGroup:self.syncMOC.dispatchGroup];
        self.applicationStatusDirectory = applicationStatusDirectory;
        self.applicationMsgStatusDirectory = msgApplicationStatusDirectory;
        [self createTranscodersWithLocalNotificationsDispatcher:localNotificationsDispatcher flowManager:flowManager applicationStatusDirectory:applicationStatusDirectory];
        
        self.eventsBuffer = [[ZMUpdateEventsBuffer alloc] initWithUpdateEventConsumer:self isHuge:NO];
        self.hugeEventsBuffer = [[ZMUpdateEventsBuffer alloc] initWithUpdateEventConsumer:self isHuge:YES];
        self.evevdHugeIdCaches = [[NSCache alloc] init];
        self.userClientRequestStrategy = [[UserClientRequestStrategy alloc] initWithClientRegistrationStatus:applicationStatusDirectory.clientRegistrationStatus
                                                                                          clientUpdateStatus:applicationStatusDirectory.clientUpdateStatus
                                                                                                     context:self.syncMOC
                                                                                               userKeysStore:self.syncMOC.zm_cryptKeyStore];
        self.missingClientsRequestStrategy = [[MissingClientsRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory];
        self.fetchingClientRequestStrategy = [[FetchingClientRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory];
        self.pushTokenStrategy = [[PushTokenStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory analytics:applicationStatusDirectory.analytics];
        self.apnsPushTokenStrategy = [[ApnsPushTokenStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory analytics:applicationStatusDirectory.analytics];
        
        self.requestStrategies = @[
                                   self.userClientRequestStrategy,
                                   self.missingClientsRequestStrategy,
                                   self.fetchingClientRequestStrategy,
                                   self.userDisableSendMsgStrategy,
                                   [[ProxiedRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory requestsStatus:applicationStatusDirectory.proxiedRequestStatus],
                                   [[DeleteAccountRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory cookieStorage: cookieStorage],
                                   [[AssetV2DownloadRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   [[AssetV3DownloadRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   [[AssetClientMessageRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   [[AssetV3PreviewDownloadRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   [[AddressBookUploadRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   [[AvailabilityRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   [[UserPropertyRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   [[UserProfileRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC
                                                                                  applicationStatus:applicationStatusDirectory
                                                                            userProfileUpdateStatus:applicationStatusDirectory.userProfileUpdateStatus],
                                   self.linkPreviewAssetDownloadRequestStrategy,
                                   self.linkPreviewAssetUploadRequestStrategy,
                                   self.imageV2DownloadRequestStrategy,
                                   self.pushTokenStrategy,
                                   self.apnsPushTokenStrategy,
                                   [[TypingStrategy alloc] initWithApplicationStatus:applicationStatusDirectory managedObjectContext:self.syncMOC],
                                   [[SearchUserImageStrategy alloc] initWithApplicationStatus:applicationStatusDirectory managedObjectContext:self.syncMOC],
                                   [[BGPMemberImageStrategy alloc] initWithApplicationStatus:applicationStatusDirectory managedObjectContext:self.syncMOC],
                                   self.connectionTranscoder,
                                   self.conversationTranscoder,
                                   self.clientMessageTranscoder,
                                   self.userTranscoder,
                                   self.lastUpdateEventIDTranscoder,
                                   [[LinkPreviewUploadRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   self.selfStrategy,
                                   self.callingRequestStrategy,
                                   [[GenericMessageNotificationRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC clientRegistrationDelegate:applicationStatusDirectory.clientRegistrationStatus],
                                   [[UserImageAssetUpdateStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatusDirectory:applicationStatusDirectory],
                                   [[ConversationAvatarUpdateStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatusDirectory:applicationStatusDirectory],
                                   [[AssetDeletionRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory identifierProvider:applicationStatusDirectory.assetDeletionStatus],
                                   [[UserRichProfileRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory],
                                   self.missingUpdateEventsTranscoder,
                                   self.missingHugeUpdateEventsTranscoder
                                   ];
        
        [self.msgMOC performGroupedBlockAndWait:^{
            self.messageRequestStrategies = @[
                [[ClientMessageTranscoder alloc] initIn:self.msgMOC localNotificationDispatcher:localNotificationsDispatcher applicationStatus: self.applicationMsgStatusDirectory],
                [[MissingClientsRequestStrategy alloc] initWithManagedObjectContext:self.msgMOC applicationStatus: self.applicationMsgStatusDirectory],
                [[FetchingClientRequestStrategy alloc] initWithManagedObjectContext:self.msgMOC applicationStatus: self.applicationMsgStatusDirectory],
                [[AssetV3UploadRequestStrategy alloc] initWithManagedObjectContext:self.msgMOC applicationStatus: self.applicationMsgStatusDirectory],
                [[AssetClientMessageRequestStrategy alloc] initWithManagedObjectContext:self.msgMOC applicationStatus: self.applicationMsgStatusDirectory],
                [[LinkPreviewUploadRequestStrategy alloc] initWithManagedObjectContext:self.msgMOC applicationStatus: self.applicationMsgStatusDirectory],
                [LinkPreviewAssetUploadRequestStrategy createWithManagedObjectContext:self.msgMOC applicationStatus: self.applicationMsgStatusDirectory]
            ];
        }];
        
        self.changeTrackerBootStrap = [[ZMChangeTrackerBootstrap alloc] initWithManagedObjectContext:self.syncMOC changeTrackers:self.allChangeTrackers];
        self.messageChangeTrackerBootStrap = [[ZMMessageChangeTrackerBootstrap alloc] initWithManagedObjectContext:self.msgMOC changeTrackers:self.messageTrackers];

        ZM_ALLOW_MISSING_SELECTOR([[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:self.syncMOC]);
        ZM_ALLOW_MISSING_SELECTOR([[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:storeProvider.contextDirectory.uiContext]);
        ZM_ALLOW_MISSING_SELECTOR([[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:storeProvider.contextDirectory.msgContext]);
        [application registerObserverForDidEnterBackground:self selector:@selector(appDidEnterBackground:)];
        [application registerObserverForWillEnterForeground:self selector:@selector(appWillEnterForeground:)];
        [application registerObserverForApplicationWillTerminate:self selector:@selector(appTerminated:)];
    }
    return self;
}

- (void)createTranscodersWithLocalNotificationsDispatcher:(LocalNotificationDispatcher *)localNotificationsDispatcher
                                              flowManager:(id<FlowManagerType>)flowManager
                               applicationStatusDirectory:(ApplicationStatusDirectory *)applicationStatusDirectory
{
    self.eventDecoder = [[EventDecoder alloc] initWithEventMOC:self.eventMOC syncMOC:self.syncMOC];
    self.hugeEventDecoder = [[HugeEventDecoder alloc] initWithEventMOC:self.eventMOC syncMOC:self.syncMOC];
    self.connectionTranscoder = [[ZMConnectionTranscoder alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory syncStatus:applicationStatusDirectory.syncStatus];
    self.userTranscoder = [[ZMUserTranscoder alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory syncStatus:applicationStatusDirectory.syncStatus];
    self.selfStrategy = [[ZMSelfStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory clientRegistrationStatus:applicationStatusDirectory.clientRegistrationStatus syncStatus:applicationStatusDirectory.syncStatus];
    self.conversationTranscoder = [[ZMConversationTranscoder alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory localNotificationDispatcher:localNotificationsDispatcher syncStatus:applicationStatusDirectory.syncStatus];
    self.clientMessageTranscoder = [[ClientMessageTranscoder alloc] initIn:self.syncMOC localNotificationDispatcher:localNotificationsDispatcher applicationStatus:applicationStatusDirectory];
    self.missingUpdateEventsTranscoder = [[ZMMissingUpdateEventsTranscoder alloc] initWithSyncStrategy:self previouslyReceivedEventIDsCollection:self.eventDecoder application:self.application applicationStatus:applicationStatusDirectory];
    self.missingHugeUpdateEventsTranscoder = [[ZMMissingHugeUpdateEventsTranscoder alloc] initWithSyncStrategy:self previouslyReceivedEventIDsCollection:self.hugeEventDecoder application:self.application applicationStatus:applicationStatusDirectory];
    self.lastUpdateEventIDTranscoder = [[ZMLastUpdateEventIDTranscoder alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory syncStatus:applicationStatusDirectory.syncStatus objectDirectory:self];
    self.callingRequestStrategy = [[CallingRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC clientRegistrationDelegate:applicationStatusDirectory.clientRegistrationStatus flowManager:flowManager callEventStatus:applicationStatusDirectory.callEventStatus];
    self.userDisableSendMsgStrategy = [[UserDisableSendMsgStatusStrategy alloc]initWithContext:self.syncMOC dispatcher:self.localNotificationDispatcher];
    self.conversationStatusSync = [[ConversationStatusStrategy alloc] initWithManagedObjectContext:self.syncMOC];
    self.linkPreviewAssetDownloadRequestStrategy = [[LinkPreviewAssetDownloadRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory];
    self.linkPreviewAssetUploadRequestStrategy = [LinkPreviewAssetUploadRequestStrategy createWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory];
    self.imageV2DownloadRequestStrategy = [[ImageV2DownloadRequestStrategy alloc] initWithManagedObjectContext:self.syncMOC applicationStatus:applicationStatusDirectory];
}

- (void)appDidEnterBackground:(NSNotification *)note
{
    NOT_USED(note);
    BackgroundActivity *activity = [BackgroundActivityFactory.sharedFactory startBackgroundActivityWithName:@"enter background"];
    [self.notificationDispatcher applicationDidEnterBackground];
//    [EditMessageProcessRecorder.shared applicationDidEnterBackground];
    [self.syncMOC performGroupedBlock:^{
        self.applicationStatusDirectory.operationStatus.isInBackground = YES;
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];

        if (activity) {
            [BackgroundActivityFactory.sharedFactory endBackgroundActivity:activity];
        }
    }];
}

- (void)appWillEnterForeground:(NSNotification *)note
{
    NOT_USED(note);
    BackgroundActivity *activity = [BackgroundActivityFactory.sharedFactory startBackgroundActivityWithName:@"enter foreground"];
    [self.notificationDispatcher applicationWillEnterForeground];
//    [EditMessageProcessRecorder.shared applicationWillEnterForeground];
    [self.syncMOC performGroupedBlock:^{
        self.applicationStatusDirectory.operationStatus.isInBackground = NO;
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];

        if (activity) {
            [BackgroundActivityFactory.sharedFactory endBackgroundActivity:activity];
        }
    }];
}

- (void)appTerminated:(NSNotification *)note
{
    NOT_USED(note);
    [self.application unregisterObserverForStateChange:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSManagedObjectContext *)moc
{
    return self.syncMOC;
}

- (void)didEstablishUpdateEventsStream
{
    [self.applicationStatusDirectory.syncStatus pushChannelDidOpen];
}

- (void)didInterruptUpdateEventsStream
{
    [self.applicationStatusDirectory.syncStatus pushChannelDidClose];
}

- (void)didFinishSync
{
    [self processAllEventsInBuffer];
    [self.hotFix applyPatches];
}

- (BOOL)isReadyToProcessEvents
{
    return !self.applicationStatusDirectory.syncStatus.isSyncing;
}

- (void)tearDown
{
    self.tornDown = YES;
    self.localNotificationDispatcher = nil;
    self.applicationStatusDirectory = nil;
    self.connectionTranscoder = nil;
    self.missingUpdateEventsTranscoder = nil;
    self.missingHugeUpdateEventsTranscoder = nil;
    self.changeTrackerBootStrap = nil;
    self.callingRequestStrategy = nil;
    self.connectionTranscoder = nil;
    self.conversationTranscoder = nil;
    self.eventsBuffer = nil;
    self.hugeEventsBuffer = nil;
    self.userTranscoder = nil;
    self.selfStrategy = nil;
    self.clientMessageTranscoder = nil;
    self.lastUpdateEventIDTranscoder = nil;
    self.allChangeTrackers = nil;
    self.eventDecoder = nil;
    self.hugeEventDecoder = nil;
    [self.eventMOC performGroupedBlockAndWait:^{
        [self.eventMOC tearDownEventMOC];
    }];
    self.eventMOC = nil;
    [self.application unregisterObserverForStateChange:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self appTerminated:nil];

    @autoreleasepool {
        for (ZMObjectSyncStrategy *s in self.requestStrategies) {
            if ([s respondsToSelector:@selector((tearDown))]) {
                [s tearDown];
            }
        }
    }
    self.requestStrategies = nil;
    [self.notificationDispatcher tearDown];
    [self.conversationStatusSync tearDown];
}

- (void)processAllEventsInBuffer
{
    [self.eventsBuffer processAllEventsInBuffer];
    [self.hugeEventsBuffer processAllEventsInBuffer];
    [self.syncMOC enqueueDelayedSave];
}


#if DEBUG
- (void)dealloc
{
    RequireString(self.tornDown, "Did not tear down %p", (__bridge void *) self);
}
#endif

- (NSArray *)allChangeTrackers
{
    if (_allChangeTrackers == nil) {
        _allChangeTrackers = [self.requestStrategies flattenWithBlock:^NSArray *(id <ZMObjectStrategy> objectSync) {
            if ([objectSync conformsToProtocol:@protocol(ZMContextChangeTrackerSource)]) {
                return objectSync.contextChangeTrackers;
            }
            return nil;
        }];
        _allChangeTrackers = [_allChangeTrackers arrayByAddingObject:self.conversationStatusSync];
    }
    
    return _allChangeTrackers;
}

- (NSArray *)messageTrackers
{
    if (_messageTrackers == nil) {
        _messageTrackers = [self.messageRequestStrategies flattenWithBlock:^NSArray *(id <ZMObjectStrategy> objectSync) {
            if ([objectSync conformsToProtocol:@protocol(ZMContextChangeTrackerSource)]) {
                return objectSync.contextChangeTrackers;
            }
            return nil;
        }];
    }
    
    return _messageTrackers;
}

- (NSArray<id<ZMEventConsumer>> *)eventConsumers
{
    if (_eventConsumers == nil) {
        NSMutableArray<id<ZMEventConsumer>> *eventConsumers = [NSMutableArray array];
        
        for (id<ZMObjectStrategy> objectStrategy in self.requestStrategies) {
            if ([objectStrategy conformsToProtocol:@protocol(ZMEventConsumer)]) {
                [eventConsumers addObject:objectStrategy];
            }
        }
        
        _eventConsumers = eventConsumers;
    }
    
    return _eventConsumers;
}

- (ZMTransportRequest *)nextRequest
{
    if(self.tornDown) {
        return nil;
    }
    return [self.requestStrategies firstNonNilReturnedFromSelector:@selector(nextRequest)];
}

- (ZMTransportRequest *)messagNextRequest
{
    if(self.tornDown) {
        return nil;
    }
    return [self.messageRequestStrategies firstNonNilReturnedFromSelector:@selector(nextRequest)];
}

- (void)startChangeTrackerBootStrap {
    [self.msgMOC performGroupedBlock:^{
        if (!self.didFetchMessageObjects) {
            self.didFetchMessageObjects = YES;
            [self.messageChangeTrackerBootStrap fetchObjectsForChangeTrackers];
            [ZMConversation deleteOlderNeedlessMessagesWithMoc: self.msgMOC];
            [ZMConversation lookMessagesWithMoc:self.msgMOC];
        }
    }];
}

- (void) saveHugeConversationMuteInfo {
    
    [self startChangeTrackerBootStrap];
    
    [self.syncMOC performGroupedBlock:^{
        if (!self.didFetchObjects) {
            self.didFetchObjects = YES;
            [self.changeTrackerBootStrap fetchObjectsForChangeTrackers];
        }
    }];
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:SaveHugeNoMuteConversationsNotificationName object:nil] postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:@[NSDefaultRunLoopMode]];
}

@end
