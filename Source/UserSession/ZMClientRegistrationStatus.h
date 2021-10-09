// 

@import WireRequestStrategy;
#import "ZMSyncStateDelegate.h"

@class ZMCredentials;
@class UserClient;
@class ZMEmailCredentials;
@class ZMPersistentCookieStorage;
@class ZMCookie;

typedef NS_ENUM(NSUInteger, ZMClientRegistrationPhase) {
    /// The client is not registered - we send out a request to register the client
    ZMClientRegistrationPhaseUnregistered = 0,
    
    /// the user is not logged in yet or has entered the wrong credentials - we don't send out any requests
    ZMClientRegistrationPhaseWaitingForLogin,
    
    /// the user is logged in but is waiting to fetch the selfUser - we send out a request to fetch the selfUser
    ZMClientRegistrationPhaseWaitingForSelfUser,
    
    /// the user has too many devices registered - we send a request to fetch all devices
    ZMClientRegistrationPhaseFetchingClients,
    
    /// the user has selected a device to delete - we send a request to delete the device
    ZMClientRegistrationPhaseWaitingForDeletion,
    
    /// the user has registered with phone but needs to register an email address and password to register a second device - we wait until we have emailCredentials
    ZMClientRegistrationPhaseWaitingForEmailVerfication,
    
    /// The client is registered
    ZMClientRegistrationPhaseRegistered
};


extern NSString *const ZMPersistedClientIdKey;


@interface ZMClientRegistrationStatus : NSObject <ClientRegistrationDelegate, TearDownCapable>

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                                      cookieStorage:(ZMPersistentCookieStorage *)cookieStorage
                  registrationStatusDelegate:(id<ZMClientRegistrationStatusDelegate>) registrationStatusDelegate;

- (void)prepareForClientRegistration;
- (BOOL)needsToRegisterClient;
+ (BOOL)needsToRegisterClientInContext:(NSManagedObjectContext *)moc;
- (BOOL)isLogin:(NSManagedObjectContext *)context;

- (void)didFetchSelfUser;
- (void)didRegisterClient:(UserClient *)client;
- (void)didFailToRegisterClient:(NSError *)error;

- (void)didDetectCurrentClientDeletion;
- (BOOL)clientIsReadyForRequests;

- (void)tearDown;

@property (nonatomic, readonly) ZMPersistentCookieStorage *cookieStorage;
@property (nonatomic, readonly) ZMClientRegistrationPhase currentPhase;
@property (nonatomic) ZMEmailCredentials *emailCredentials;

@end
