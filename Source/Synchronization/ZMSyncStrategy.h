// 



@import Foundation;
@import WireRequestStrategy;

#import "ZMObjectStrategyDirectory.h"
#import "ZMUpdateEventsBuffer.h"

@class ZMTransportRequest;
@class ZMPushChannelConnection;
@class ZMAuthenticationStatus;
@class LocalNotificationDispatcher;
@class UserProfileUpdateStatus;
@class ProxiedRequestsStatus;
@class ZMClientRegistrationStatus;
@class ClientUpdateStatus;
@class BackgroundAPNSPingBackStatus;
@class ZMAccountStatus;
@class ApplicationStatusDirectory;
@class CallingRequestStrategy;
@class EventDecoder;
@class HugeEventDecoder;

@protocol ZMTransportData;
@protocol ZMSyncStateDelegate;
@protocol ZMBackgroundable;
@protocol ApplicationStateOwner;
@protocol FlowManagerType;
@protocol ZMApplication;
@protocol LocalStoreProviderProtocol;
@protocol EventProcessingTrackerProtocol;

@interface ZMSyncStrategy : NSObject <ZMObjectStrategyDirectory, TearDownCapable>

- (instancetype _Nonnull )initWithStoreProvider:(id<LocalStoreProviderProtocol> _Nonnull)storeProvider
                                  cookieStorage:(ZMPersistentCookieStorage * _Nullable)cookieStorage
                                    flowManager:(id<FlowManagerType> _Nonnull)flowManager
                   localNotificationsDispatcher:(LocalNotificationDispatcher * _Nonnull)localNotificationsDispatcher
                        notificationsDispatcher:(NotificationDispatcher * _Nonnull)notificationsDispatcher
                     applicationStatusDirectory:(ApplicationStatusDirectory * _Nonnull)applicationStatusDirectory
                    msgApplicationStatusDirectory:(ApplicationStatusDirectory * _Nonnull)msgApplicationStatusDirectory
                                    application:(id<ZMApplication> _Nonnull)application;

- (void)didInterruptUpdateEventsStream;
- (void)didEstablishUpdateEventsStream;
- (void)didFinishSync;

- (ZMTransportRequest *_Nullable)nextRequest;
- (ZMTransportRequest *_Nullable)messagNextRequest;

- (void)tearDown;

- (void) saveHugeConversationMuteInfo;

@property (nonatomic, readonly, nonnull) NSManagedObjectContext *syncMOC;
@property (nonatomic, readonly, nonnull) NSManagedObjectContext *msgMOC;
@property (nonatomic, weak, readonly, nullable) ApplicationStatusDirectory *applicationStatusDirectory;
@property (nonatomic, readonly, nonnull) CallingRequestStrategy *callingRequestStrategy;
@property (nonatomic, readonly, nonnull) HugeEventDecoder *hugeEventDecoder;
@property (nonatomic, readonly, nonnull) EventDecoder *eventDecoder;
@property (nonatomic, readonly, nonnull) ZMUpdateEventsBuffer *eventsBuffer;
@property (nonatomic, readonly, nonnull) ZMUpdateEventsBuffer *hugeEventsBuffer;
@property (nonatomic, readonly, nonnull) NSArray<id<ZMEventConsumer>> *eventConsumers;
@property (nonatomic, weak, readonly, nullable) LocalNotificationDispatcher *localNotificationDispatcher;
@property (nonatomic, readonly) BOOL isReadyToProcessEvents;
@property (nonatomic, nullable) id<EventProcessingTrackerProtocol> eventProcessingTracker;
@property (nonatomic, readonly, nonnull) NSCache<NSString *, NSString *> *evevdHugeIdCaches;

@end

