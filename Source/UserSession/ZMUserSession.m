// 


@import UIKit;
@import CoreData;
@import WireSystem;
@import WireUtilities;
@import WireDataModel;
@import CoreTelephony;
@import WireTransport;

#import "ZMUserSession+Background.h"
#import "ZMUserSession+Internal.h"
#import "ZMUserSession+OperationLoop.h"
#import "ZMSyncStrategy.h"
#import "NSError+ZMUserSessionInternal.h"
#import "ZMCredentials.h"
#import <libkern/OSAtomic.h>
#import "ZMAuthenticationStatus.h"
#import "ZMBlacklistVerificator.h"
#import "NSURL+LaunchOptions.h"
#import "WireSyncEngineLogs.h"
#import "ZMOperationLoop+Private.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>
#import "ZMClientRegistrationStatus.h"

NSString * const ZMPhoneVerificationCodeKey = @"code";
NSNotificationName const ZMLaunchedWithPhoneVerificationCodeNotificationName = @"ZMLaunchedWithPhoneVerificationCode";
NSNotificationName const ZMUserSessionResetPushTokensNotificationName = @"ZMUserSessionResetPushTokensNotification";

static NSString * const AppstoreURL = @"https://itunes.apple.com/us/app/zeta-client/id930944768?ls=1&mt=8";


@interface ZMUserSession ()
@property (nonatomic) ZMSyncStrategy *syncStrategy;
@property (nonatomic) ZMOperationLoop *operationLoop;
@property (nonatomic) ZMTransportRequest *runningLoginRequest;
@property (nonatomic) id<TransportSessionType> transportSession;
@property (atomic) ZMNetworkState networkState;
@property (nonatomic) ZMBlacklistVerificator *blackList;
@property (nonatomic) NotificationDispatcher *notificationDispatcher;
@property (nonatomic) LocalNotificationDispatcher *localNotificationDispatcher;
@property (nonatomic) NSMutableArray* observersToken;
@property (nonatomic) ApplicationStatusDirectory *applicationStatusDirectory;
@property (nonatomic) ApplicationStatusDirectory *applicationMsgStatusDirectory;

@property (nonatomic) TopConversationsDirectory *topConversationsDirectory;
@property (nonatomic) BOOL hasCompletedInitialSync;
@property (nonatomic) BOOL tornDown;


/// Build number of the Wire app
@property (nonatomic) NSString *appVersion;

/// map from NSUUID to ZMCommonContactsSearchCachedEntry
@property (nonatomic) NSCache *commonContactsCache;

@property (nonatomic) id<MediaManagerType> mediaManager;
@property (nonatomic) id<FlowManagerType> flowManager;
@end

@interface ZMUserSession(PushChannel)
- (void)pushChannelDidChange:(NotificationInContext *)note;
@end

@implementation ZMUserSession

ZM_EMPTY_ASSERTING_INIT()

- (void)dealloc
{
    Require(self.tornDown);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithMediaManager:(id<MediaManagerType>)mediaManager
                         flowManager:(id<FlowManagerType>)flowManager
                           analytics:(id<AnalyticsType>)analytics
                    transportSession:(id<TransportSessionType>)transportSession
                         application:(id<ZMApplication>)application
                          appVersion:(NSString *)appVersion
                       storeProvider:(id<LocalStoreProviderProtocol>)storeProvider;
{
    [storeProvider.contextDirectory.syncContext performBlockAndWait:^{
        storeProvider.contextDirectory.syncContext.analytics = analytics;
    }];

    RequestLoopAnalyticsTracker *tracker = [[RequestLoopAnalyticsTracker alloc] initWithAnalytics:analytics];
    
    if ([transportSession respondsToSelector:@selector(setRequestLoopDetectionCallback:)]) {
        ((ZMTransportSession *)transportSession).requestLoopDetectionCallback = ^(NSString *path) {
            // The tracker will return NO in case the path should be ignored.
            if (! [tracker tagWithPath:path]) {
                return;
            }
            ZMLogWarn(@"Request loop happening at path: %@", path);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:ZMLoggingRequestLoopNotificationName object:nil userInfo:@{@"path" : path}];
            });
        };
    }
    
    self = [self initWithTransportSession:transportSession
                             mediaManager:mediaManager
                              flowManager:flowManager
                                analytics:analytics
                            operationLoop:nil
                              application:application
                               appVersion:appVersion
                            storeProvider:storeProvider];
    return self;
}

- (instancetype)initWithTransportSession:(id<TransportSessionType>)transportSession
                            mediaManager:(id<MediaManagerType>)mediaManager
                             flowManager:(id<FlowManagerType>)flowManager
                               analytics:(id<AnalyticsType>)analytics
                           operationLoop:(ZMOperationLoop *)operationLoop
                             application:(id<ZMApplication>)application
                              appVersion:(NSString *)appVersion
                            storeProvider:(id<LocalStoreProviderProtocol>)storeProvider
{
    self = [super init];
    if(self) {
        _storeProvider = storeProvider;
        self.observersToken = [[NSMutableArray alloc] init];
        
        self.appVersion = appVersion;
        [ZMUserAgent setWireAppVersion:appVersion];
        self.pushChannelIsOpen = NO;

        ZM_WEAK(self);
        [self.observersToken addObject:[NotificationInContext
                                         addObserverWithName:ZMOperationLoop.pushChannelStateChangeNotificationName
                                         context: self.managedObjectContext.notificationContext
                                         object:nil
                                         queue:nil
                                         using:^(NotificationInContext *note) {
                                             ZM_STRONG(self);
                                             [self pushChannelDidChange:note];
                                         }
        ]];
        self.networkIsOnline = YES;
        self.managedObjectContext.isOffline = NO;
        
        [self.syncManagedObjectContext performBlockAndWait:^{
            self.syncManagedObjectContext.zm_userInterfaceContext = self.managedObjectContext;
            self.syncManagedObjectContext.zm_msgContext = self.msgManagedObjectContext;
        }];
        [self.msgManagedObjectContext performBlockAndWait:^{
            self.msgManagedObjectContext.zm_userInterfaceContext = self.managedObjectContext;
        }];
        self.managedObjectContext.zm_syncContext = self.syncManagedObjectContext;
        
        NSURL *cacheLocation = [NSFileManager.defaultManager cachesURLForAccountWith:storeProvider.userIdentifier in:storeProvider.applicationContainer];
        [self.class moveCachesIfNeededForAccountWith:storeProvider.userIdentifier in:storeProvider.applicationContainer];
        
        UserImageLocalCache *userImageCache = [[UserImageLocalCache alloc] initWithLocation:cacheLocation];
        self.managedObjectContext.zm_userImageCache = userImageCache;
        
        ConversationAvatarLocalCache *conversationAvatarCache = [[ConversationAvatarLocalCache alloc] initWithLocation:cacheLocation];
        self.managedObjectContext.zm_conversationAvatarCache = conversationAvatarCache;
        
        FileAssetCache *fileAssetCache = [[FileAssetCache alloc] initWithLocation:cacheLocation];
        self.managedObjectContext.zm_fileAssetCache = fileAssetCache;
        
        self.managedObjectContext.zm_searchUserCache = [[NSCache alloc] init];
        self.managedObjectContext.zm_BGPMemberAssetCache = [[NSCache alloc] init];
        
        self.notificationDispatcher = [[NotificationDispatcher alloc] initWithManagedObjectContext:self.managedObjectContext];
        
        [self.syncManagedObjectContext performGroupedBlockAndWait:^{
            self.applicationStatusDirectory = [[ApplicationStatusDirectory alloc] initWithManagedObjectContext:self.syncManagedObjectContext
                                                                                                   cookieStorage:transportSession.cookieStorage
                                                                                             requestCancellation:transportSession
                                                                                                     application:application
                                                                                               syncStateDelegate:self
                                                                                                       analytics:analytics];
            
            self.syncManagedObjectContext.zm_userImageCache = userImageCache;
            self.syncManagedObjectContext.zm_conversationAvatarCache = conversationAvatarCache;
            self.syncManagedObjectContext.zm_fileAssetCache = fileAssetCache;
            
            self.localNotificationDispatcher = [[LocalNotificationDispatcher alloc] initWithManagedObjectContext:self.syncManagedObjectContext];
            
            self.callStateObserver = [[ZMCallStateObserver alloc] initWithLocalNotificationDispatcher:self.localNotificationDispatcher contextProvider:self callNotificationStyleProvider:self];
            
            self.transportSession = transportSession;
            self.transportSession.pushChannel.clientID = self.selfUserClient.remoteIdentifier;
            [self.transportSession setNetworkStateDelegate:self];
            self.mediaManager = mediaManager;
            self.hasCompletedInitialSync = !self.applicationStatusDirectory.syncStatus.isSlowSyncing;
        }];
        
        [self.msgManagedObjectContext performGroupedBlockAndWait:^{
            self.msgManagedObjectContext.zm_userImageCache = userImageCache;
            self.msgManagedObjectContext.zm_conversationAvatarCache = conversationAvatarCache;
            self.msgManagedObjectContext.zm_fileAssetCache = fileAssetCache;
            self.applicationMsgStatusDirectory = [[ApplicationStatusDirectory alloc] initWithManagedObjectContext:self.msgManagedObjectContext
                  cookieStorage:transportSession.cookieStorage
            requestCancellation:transportSession
                    application:application
              syncStateDelegate:self
                      analytics:analytics];
        }];

        _application = application;
        self.topConversationsDirectory = [[TopConversationsDirectory alloc] initWithManagedObjectContext:self.managedObjectContext];
        
        [self.syncManagedObjectContext performBlockAndWait:^{
            
            self.syncStrategy = [[ZMSyncStrategy alloc] initWithStoreProvider:storeProvider
                                                                cookieStorage:transportSession.cookieStorage
                                                                  flowManager:flowManager
                                                 localNotificationsDispatcher:self.localNotificationDispatcher
                                                      notificationsDispatcher:self.notificationDispatcher
                                                   applicationStatusDirectory:self.applicationStatusDirectory
                                                msgApplicationStatusDirectory:self.applicationMsgStatusDirectory
                                                                  application:application];
            
            self.operationLoop = operationLoop ?: [[ZMOperationLoop alloc] initWithTransportSession:transportSession
                                                                                       syncStrategy:self.syncStrategy
                                                                         applicationStatusDirectory:self.applicationStatusDirectory
                                                                                              uiMOC:self.managedObjectContext
                                                                                            syncMOC:self.syncManagedObjectContext
                                                                                             msgMOC:self.msgManagedObjectContext];
            
            __weak id weakSelf = self;
            [transportSession setAccessTokenRenewalFailureHandler:^(ZMTransportResponse * _Nonnull response) {
                ZMUserSession *strongSelf = weakSelf;
                [strongSelf transportSessionAccessTokenDidFail:response];
            }];
            [self startEphemeralTimers];
        }];
        
        if ([transportSession isKindOfClass:[ZMTransportSession class]]) {
            ((ZMTransportSession *)transportSession).accessTokenDelegate = self;
        }
        
        self.commonContactsCache = [[NSCache alloc] init];
        self.commonContactsCache.name = @"ZMUserSession commonContactsCache";
        
        [self registerForRegisteringPushTokenNotification];
        [self registerForBackgroundNotifications];
        
        [self enableBackgroundFetch];

        self.storedDidSaveNotifications = [[ContextDidSaveNotificationPersistence alloc] initWithAccountContainer:self.storeProvider.accountContainer];
        [self observeChangesOnShareExtension];
        
        
        [self.syncManagedObjectContext performGroupedBlockAndWait:^{
            if (self.clientRegistrationStatus.currentPhase != ZMClientRegistrationPhaseRegistered) {
                [self.clientRegistrationStatus prepareForClientRegistration];
            }
            
            [self.localNotificationDispatcher notifyAvailabilityBehaviourChangedIfNeeded];
        }];
        
        self.userExpirationObserver = [[UserExpirationObserver alloc] initWithManagedObjectContext:self.managedObjectContext];
        
        [UserAliasname getAliasName];
        
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
        [ZMRequestAvailableNotification msgNotifyNewRequestsAvailable:self];
    }
    return self;
}

- (void)tearDown
{
    [self.observersToken removeAllObjects];
    [self.application unregisterObserverForStateChange:self];
    self.mediaManager = nil;
    self.callStateObserver = nil;
    [self.syncStrategy tearDown];
    self.syncStrategy = nil;
    [self.operationLoop tearDown];
    self.operationLoop = nil;
    [self.transportSession tearDown];
    self.transportSession = nil;
    self.applicationStatusDirectory = nil;
    
    [self.localNotificationDispatcher tearDown];
    self.localNotificationDispatcher = nil;
    [self.blackList tearDown];
    
    __block NSMutableArray *keysToRemove = [NSMutableArray array];
    [self.managedObjectContext.userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL * ZM_UNUSED stop) {
        if ([obj respondsToSelector:@selector((tearDown))]) {
            [obj tearDown];
            [keysToRemove addObject:key];
        }
    }];
    [self.managedObjectContext.userInfo removeObjectsForKeys:keysToRemove];
    [keysToRemove removeAllObjects];
    [self.syncManagedObjectContext performBlockAndWait:^{
        [self.managedObjectContext.userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL * ZM_UNUSED stop) {
            if ([obj respondsToSelector:@selector((tearDown))]) {
                [obj tearDown];
            }
            [keysToRemove addObject:key];
        }];
        [self.syncManagedObjectContext.userInfo removeObjectsForKeys:keysToRemove];
    }];
    
    NSManagedObjectContext *uiMoc = self.managedObjectContext;
    _storeProvider = nil;
    
    BOOL shouldWaitOnUiMoc = !([NSOperationQueue currentQueue] == [NSOperationQueue mainQueue] && uiMoc.concurrencyType == NSMainQueueConcurrencyType);
    
    if(shouldWaitOnUiMoc)
    {
        [uiMoc performBlockAndWait:^{ // warning: this will hang if the uiMoc queue is same as self.requestQueue (typically uiMoc queue is the main queue)
            // nop
        }];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.blackList = nil;
    self.tornDown = YES;
}

- (BOOL)isNotificationContentHidden;
{
    return [[self.managedObjectContext persistentStoreMetadataForKey:LocalNotificationDispatcher.ZMShouldHideNotificationContentKey] boolValue];
}

- (void)setIsNotificationContentHidden:(BOOL)isNotificationContentHidden;
{
    [self.managedObjectContext setPersistentStoreMetadata:@(isNotificationContentHidden) forKey:LocalNotificationDispatcher.ZMShouldHideNotificationContentKey];
}

- (BOOL)isLoggedIn
{
    return self.authenticationStatus.isAuthenticated &&
    [self.clientRegistrationStatus isLogin: self.msgManagedObjectContext];
}

- (void)registerForBackgroundNotifications;
{
    [self.application registerObserverForDidEnterBackground:self selector:@selector(applicationDidEnterBackground:)];
    [self.application registerObserverForWillEnterForeground:self selector:@selector(applicationWillEnterForeground:)];
}

- (NSManagedObjectContext *)managedObjectContext
{
    return self.storeProvider.contextDirectory.uiContext;
}

- (NSManagedObjectContext *)syncManagedObjectContext
{
    return self.storeProvider.contextDirectory.syncContext;
}

- (NSManagedObjectContext *)msgManagedObjectContext
{
    return self.storeProvider.contextDirectory.msgContext;
}

- (NSManagedObjectContext *)searchManagedObjectContext
{
    return self.storeProvider.contextDirectory.searchContext;
}

- (NSURL *)sharedContainerURL
{
    return self.storeProvider.applicationContainer;
}

- (void)saveOrRollbackChanges;
{
    [self.managedObjectContext saveOrRollback];
}

- (void)performChanges:(dispatch_block_t)block;
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlockAndWait:^{
        ZM_STRONG(self);
        block();
        [self saveOrRollbackChanges];
    }];
}

- (void)enqueueChanges:(dispatch_block_t)block
{
    [self enqueueChanges:block completionHandler:nil];
}

- (void)enqueueChanges:(dispatch_block_t)block completionHandler:(dispatch_block_t)completionHandler;
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        block();
        [self saveOrRollbackChanges];
        
        if (completionHandler != nil) {
            completionHandler();
        }
    }];
}

- (void)enqueueDelayedChanges:(dispatch_block_t)block
{
    [self enqueueChanges:block completionHandler:nil];
}

- (void)enqueueDelayedChanges:(dispatch_block_t)block completionHandler:(dispatch_block_t)completionHandler;
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        block();
        
        ZMSDispatchGroup *group = [ZMSDispatchGroup groupWithLabel:@"enqueueDelayedChanges"];
        
        [self.managedObjectContext enqueueDelayedSaveWithGroup:group];
        
        [group notifyOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) block:^{
            [self.managedObjectContext performGroupedBlock:^{
                if (completionHandler != nil) {
                    completionHandler();
                }
            }];
        }];
    }];
}

- (void)initiateUserDeletion
{
    [self.syncManagedObjectContext performGroupedBlock:^{
        [self.syncManagedObjectContext setPersistentStoreMetadata:@YES forKey:[DeleteAccountRequestStrategy userDeletionInitiatedKey]];
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
    }];
}

- (void)openAppstore
{
    NSURL *appStoreURL = [NSURL URLWithString:AppstoreURL];
    if ([[UIApplication sharedApplication] canOpenURL:appStoreURL]) {
        [[UIApplication sharedApplication] openURL:appStoreURL options:@{} completionHandler:NULL];
        [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(didNotUpdateApp:) userInfo:nil repeats:NO];
    }
}

- (void)didNotUpdateApp:(NSTimer *)timer;
{
    NOT_USED(timer);
    __builtin_trap();
}

- (void)transportSessionAccessTokenDidFail:(ZMTransportResponse *)response
{
    ZMLogWithLevelAndTag(ZMLogLevelDebug, ZMTAG_NETWORK, @"Access token fail in %@: %@", self.class, NSStringFromSelector(_cmd));
    NOT_USED(response);
    
    [self.managedObjectContext performGroupedBlock:^{
        ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
        [PostLoginAuthenticationNotification notifyAuthenticationInvalidatedWithError:[NSError userSessionErrorWithErrorCode:ZMUserSessionAccessTokenExpired userInfo:selfUser.loginCredentials.dictionaryRepresentation] context:self.managedObjectContext];
    }];
}

- (void)notifyThirdPartyServices;
{
    if (! self.didNotifyThirdPartyServices) {
        self.didNotifyThirdPartyServices = YES;
        [self.thirdPartyServicesDelegate userSessionIsReadyToUploadServicesData:self];
    }
}

- (void)migrateOldAliasname {
//    [UserAliasname migrateOldAliasnameWith:self.syncManagedObjectContext];
}

- (OperationStatus *)operationStatus
{
    return self.applicationStatusDirectory.operationStatus;
}

- (void)uiFinished {
    self.notificationDispatcher.isDisabled = NO;
    [self.syncStrategy saveHugeConversationMuteInfo];
}

- (void)markAsAllRead {
    RequireString([NSThread currentThread].isMainThread, "markAsAllRead can only called in MainThread");
    for (ZMConversation *convsation in self.managedObjectContext.conversationListDirectory.unreadMessageConversations) {
        [convsation markAsRead];
    }
}

-(void)handlerDidReceiveAccessToken:(ZMAccessTokenHandler *)handler {
    [self.accessTokenHandlerDelegate handlerDidReceiveAccessToken:handler];
}

- (void)handlerDidClearAccessToken:(ZMAccessTokenHandler *)handler {
    [self.accessTokenHandlerDelegate handlerDidClearAccessToken:handler];
}

@end


@implementation ZMUserSession (PushToken)

- (BOOL)isAuthenticated
{
    return self.authenticationStatus.isAuthenticated;
}

@end



@implementation ZMUserSession (Transport)

- (void)addCompletionHandlerForBackgroundURLSessionWithIdentifier:(NSString *)identifier handler:(dispatch_block_t)handler
{
    [self.transportSession addCompletionHandlerForBackgroundSessionWithIdentifier:identifier handler:handler];
}

@end






@implementation ZMUserSession(NetworkState)

- (void)changeNetworkStateAndNotify;
{
    ZMNetworkState state;
    if (self.networkIsOnline) {
        if (self.isPerformingSync) {
            state = ZMNetworkStateOnlineSynchronizing;
        } else {
            state = ZMNetworkStateOnline;
        }
        self.managedObjectContext.isOffline = NO;
    } else {
        state = ZMNetworkStateOffline;
        self.managedObjectContext.isOffline = YES;
    }
    
    ZMNetworkState const previous = self.networkState;
    self.networkState = state;
    
    if (previous != self.networkState) {
        [ZMNetworkAvailabilityChangeNotification notifyWithNetworkState:self.networkState userSession:self];
    }
}

- (void)didReceiveData
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        self.networkIsOnline = YES;
        [self changeNetworkStateAndNotify];
    }];
}

- (void)didGoOffline
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        self.networkIsOnline = NO;
        
        [self changeNetworkStateAndNotify];
        [self saveOrRollbackChanges];
    }];
}

- (void)didStartSlowSync
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        self.isPerformingSync = YES;
        [self changeNetworkStateAndNotify];
        [self migrateOldAliasname];
    }];
}

- (void)didFinishSlowSync
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        self.hasCompletedInitialSync = YES;
        [ZMUserSession notifyInitialSyncCompletedWithContext:self.managedObjectContext];
    }];
}

- (void)didStartQuickSync
{
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        self.isPerformingSync = YES;
        [self changeNetworkStateAndNotify];
    }];
}

- (void)didFinishQuickSync
{
    [self.syncStrategy didFinishSync];
    
    ZM_WEAK(self);
    [self.managedObjectContext performGroupedBlock:^{
        ZM_STRONG(self);
        self.isPerformingSync = NO;
        [self changeNetworkStateAndNotify];
        [self notifyThirdPartyServices];
    }];
}

- (void)didRegisterUserClient:(UserClient *)userClient
{
    self.transportSession.pushChannel.clientID = userClient.remoteIdentifier;
    // If during registration user allowed notifications,
    // The push token can only be registered after client registration
    [self registerCurrentPushToken];
}

@end

@implementation ZMUserSession(PushChannel)

- (void)pushChannelDidChange:(NotificationInContext *)note
{
    BOOL newValue = [note.userInfo[ZMPushChannelIsOpenKey] boolValue];
    self.pushChannelIsOpen = newValue;
}

@end



@implementation NSManagedObjectContext (NetworkState)

static NSString * const IsOfflineKey = @"IsOfflineKey";

- (void)setIsOffline:(BOOL)isOffline;
{
    self.userInfo[IsOfflineKey] = [NSNumber numberWithBool:isOffline];
}

- (BOOL)isOffline;
{
    return [self.userInfo[IsOfflineKey] boolValue];
}

@end


@implementation ZMUserSession (LaunchOptions)

- (void)didLaunchWithURL:(NSURL *)URL;
{
    if ([URL isURLForPhoneVerification]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:ZMLaunchedWithPhoneVerificationCodeNotificationName
                                                            object:nil
                                                          userInfo:@{ ZMPhoneVerificationCodeKey : [URL codeForPhoneVerification] }];
    }
}

@end



@implementation ZMUserSession (Calling)

- (CallingRequestStrategy *)callingStrategy
{
    return self.operationLoop.syncStrategy.callingRequestStrategy;
}

@end



@implementation ZMUserSession (SelfUserClient)

- (id<UserProfile>)userProfile
{
    return self.userProfileUpdateStatus;
}

- (UserClient *)selfUserClient
{
    return [ZMUser selfUserInContext:self.managedObjectContext].selfClient;
}

@end



@implementation ZMUserSession (AuthenticationStatus)

- (id<AuthenticationStatusProvider>)authenticationStatus
{
    return self.transportSession.cookieStorage;
}

- (UserProfileUpdateStatus *)userProfileUpdateStatus;
{
    return self.applicationStatusDirectory.userProfileUpdateStatus;
}

- (ZMClientRegistrationStatus *)clientRegistrationStatus;
{
    return self.applicationStatusDirectory.clientRegistrationStatus;
}

- (ClientUpdateStatus *)clientUpdateStatus;
{
    return self.applicationStatusDirectory.clientUpdateStatus;
}

- (AccountStatus *)accountStatus;
{
    return self.applicationStatusDirectory.accountStatus;
}

- (ProxiedRequestsStatus *)proxiedRequestStatus;
{
    return self.applicationStatusDirectory.proxiedRequestStatus;
}

@end

@implementation ZMUserSession (ProfilePictureUpdate)

- (id<UserProfileImageUpdateProtocol>)profileUpdate
{
    return self.applicationStatusDirectory.userProfileImageUpdateStatus;
}

@end

@implementation ZMUserSession (ConversationAvatarUpdate)

- (id<ConversationAvatarUpdateProtocol>)converastionAvatarUpdate
{
    return self.operationLoop.syncStrategy.applicationStatusDirectory.converastionAvatarUpdateStatus;
}

@end
