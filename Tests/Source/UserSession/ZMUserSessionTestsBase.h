// 


#import <CoreData/CoreData.h>
#import <WireTransport/WireTransport.h>
#import <WireDataModel/WireDataModel.h>

#import "MessagingTest.h"
#import "ZMUserSession+Internal.h"
# import "ZMUserSession+Background.h"
# import "ZMUserSession+Authentication.h"
# import "ZMUserSession+Registration.h"
# import "ZMUserSessionRegistrationNotification.h"

#import "NSError+ZMUserSessionInternal.h"
#import "ZMCredentials.h"
#import "ZMSyncStrategy.h"
#import "ZMOperationLoop.h"

#import "ZMCredentials.h"
#import "NSURL+LaunchOptions.h"

#import <WireSyncEngine/ZMAuthenticationStatus.h>

@class FlowManagerMock;
@class MockSessionManager;

@interface ThirdPartyServices : NSObject <ZMThirdPartyServicesDelegate>

@property (nonatomic) NSUInteger uploadCount;

@end

@protocol LocalStoreProviderProtocol;

@interface MockLocalStoreProvider : NSObject <LocalStoreProviderProtocol>

@property (nonatomic, copy) NSUUID *userIdentifier;
@property (nonatomic, copy) NSURL *applicationContainer;
@property (nonatomic, copy) NSURL *accountContainer;
@property (nonatomic, strong) ManagedObjectContextDirectory *contextDirectory;

- (instancetype)initWithSharedContainerDirectory:(NSURL *)sharedContainerDirectory userIdentifier:(NSUUID *)userIdentifier contextDirectory:(ManagedObjectContextDirectory *)contextDirectory;

@end

@interface ZMUserSessionTestsBase : MessagingTest <ZMAuthenticationStatusObserver>

@property (nonatomic) MockSessionManager *mockSessionManager;
@property (nonatomic) id transportSession;
@property (nonatomic) ZMTransportRequest *lastEnqueuedRequest;
@property (nonatomic) ZMPersistentCookieStorage *cookieStorage;
@property (nonatomic) NSData *validCookie;
@property (nonatomic, copy) ZMCompletionHandlerBlock authFailHandler;
@property (nonatomic, copy) ZMAccessTokenHandlerBlock tokenSuccessHandler;
@property (nonatomic) NSURL *baseURL;
@property (nonatomic) ZMUserSession *sut;
@property (nonatomic) ZMSyncStrategy *syncStrategy;
@property (nonatomic) id mediaManager;
@property (nonatomic) FlowManagerMock *flowManagerMock;
@property (nonatomic) NSUInteger dataChangeNotificationsCount;
@property (nonatomic) ThirdPartyServices *thirdPartyServices;
@property (nonatomic) id requestAvailableNotification;
@property (nonatomic) id operationLoop;
@property (nonatomic) ZMClientRegistrationStatus * clientRegistrationStatus;
@property (nonatomic) ProxiedRequestsStatus *proxiedRequestStatus;
@property (nonatomic) id<LocalStoreProviderProtocol> storeProvider;

- (void)simulateLoggedInUser;

@end
