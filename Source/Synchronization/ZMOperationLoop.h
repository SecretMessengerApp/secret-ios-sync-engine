// 
@import Foundation;

@protocol ZMSyncStateDelegate;
@protocol ZMApplication;
@protocol LocalStoreProviderProtocol;
@protocol FlowManagerType;
@protocol TransportSessionType;

@class ZMPersistentCookieStorage;
@class ApplicationStatusDirectory;
@class ZMSyncStrategy;

extern NSString * const ZMPushChannelIsOpenKey;

@interface ZMOperationLoop : NSObject <TearDownCapable>

@property (nonatomic, readonly) id<ZMApplication> application;
@property (nonatomic, readonly) id<TransportSessionType> transportSession;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTransportSession:(id<TransportSessionType>)transportSession
                            syncStrategy:(ZMSyncStrategy *)syncStrategy
              applicationStatusDirectory:(ApplicationStatusDirectory *)applicationStatusDirectory
                                   uiMOC:(NSManagedObjectContext *)uiMOC
                                 syncMOC:(NSManagedObjectContext *)syncMOC
                                 msgMOC:(NSManagedObjectContext *)msgMOC;

- (void)tearDown;

@end


