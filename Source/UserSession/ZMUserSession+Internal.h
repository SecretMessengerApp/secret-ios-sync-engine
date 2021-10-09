// 


@import WireUtilities;
@import WireTransport;
@import WireDataModel;

#import "ZMUserSession.h"
#import <WireSyncEngine/ZMAuthenticationStatus.h>
#import "ZMSyncStateDelegate.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

@class NSManagedObjectContext;
@class ZMTransportRequest;
@class ZMCredentials;
@class ZMSyncStrategy;
@class ZMOperationLoop;
@class ZMPushRegistrant;
@class UserProfileUpdateStatus;
@class ClientUpdateStatus;
@class CallKitDelegate;

@protocol MediaManagerType; 
@protocol FlowManagerType;


@interface ZMUserSession (AuthenticationStatus)

@property (nonatomic, readonly) UserProfileUpdateStatus *userProfileUpdateStatus;
@property (nonatomic, readonly) ZMClientRegistrationStatus *clientRegistrationStatus;
@property (nonatomic, readonly) ClientUpdateStatus *clientUpdateStatus;
@property (nonatomic, readonly) ProxiedRequestsStatus *proxiedRequestStatus;
@property (nonatomic, readonly) id<AuthenticationStatusProvider> authenticationStatus;

@end


@interface ZMUserSession ()

@property (nonatomic, readonly) id<ZMApplication> application;
@property (nonatomic) ZMCallStateObserver *callStateObserver;
@property (nonatomic) ContextDidSaveNotificationPersistence *storedDidSaveNotifications;
@property (nonatomic) ManagedObjectContextChangeObserver *messageReplyObserver;
@property (nonatomic) ManagedObjectContextChangeObserver *likeMesssageObserver;
@property (nonatomic)  UserExpirationObserver *userExpirationObserver;
@property (nonatomic, readonly) NSURL *sharedContainerURL;

- (void)notifyThirdPartyServices;

@end



@interface ZMUserSession (Internal) <TearDownCapable>

@property (nonatomic, readonly) BOOL isLoggedIn;
@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) NSManagedObjectContext *msgManagedObjectContext;
@property (nonatomic, readonly) NSManagedObjectContext *syncManagedObjectContext;
@property (nonatomic, readonly) LocalNotificationDispatcher *localNotificationDispatcher;

+ (NSString *)databaseIdentifier;

- (instancetype)initWithTransportSession:(id<TransportSessionType>)tranportSession
                            mediaManager:(id<MediaManagerType>)mediaManager
                             flowManager:(id<FlowManagerType>)flowManager
                               analytics:(id<AnalyticsType>)analytics
                           operationLoop:(ZMOperationLoop *)operationLoop
                             application:(id<ZMApplication>)application
                              appVersion:(NSString *)appVersion
                           storeProvider:(id<LocalStoreProviderProtocol>)storeProvider;

@end


@interface ZMUserSession (ClientRegistrationStatus) <ZMClientRegistrationStatusDelegate>
@end


@interface ZMUserSession(NetworkState) <ZMNetworkStateDelegate, ZMSyncStateDelegate>
@end


@interface NSManagedObjectContext (NetworkState)

@property BOOL isOffline;

@end


@interface ZMUserSession (ZMBackgroundFetch)

- (void)enableBackgroundFetch;

@end
