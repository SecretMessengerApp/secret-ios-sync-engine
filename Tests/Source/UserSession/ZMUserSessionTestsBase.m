// 


#import <Foundation/Foundation.h>
#include "ZMUserSessionTestsBase.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"
@import WireSyncEngine;


@implementation MockLocalStoreProvider

- (instancetype)initWithSharedContainerDirectory:(NSURL *)sharedContainerDirectory userIdentifier:(NSUUID *)userIdentifier contextDirectory:(ManagedObjectContextDirectory *)contextDirectory
{
    self = [super init];
    if (self) {
        self.userIdentifier = userIdentifier;
        self.accountContainer = [[sharedContainerDirectory URLByAppendingPathComponent:@"AccountData"] URLByAppendingPathComponent:userIdentifier.UUIDString];
        self.applicationContainer = sharedContainerDirectory;
        self.contextDirectory = contextDirectory;
    }
    return self;
}

@end

@implementation ThirdPartyServices

- (void)userSessionIsReadyToUploadServicesData:(ZMUserSession *)userSession;
{
    NOT_USED(userSession);
    ++self.uploadCount;
}

@end


@interface ZMUserSessionTestsBase ()

@property (nonatomic) OperationStatus *operationStatus;

@end



@implementation ZMUserSessionTestsBase

- (void)setUp
{
    [super setUp];
    
    WireCallCenterV3Factory.wireCallCenterClass = WireCallCenterV3Mock.self;
    
    self.thirdPartyServices = [[ThirdPartyServices alloc] init];
    self.dataChangeNotificationsCount = 0;
    self.baseURL = [NSURL URLWithString:@"http://bar.example.com"];
    self.transportSession = [OCMockObject niceMockForClass:[ZMTransportSession class]];
    self.cookieStorage = [ZMPersistentCookieStorage storageForServerName:@"usersessiontest.example.com" userIdentifier:NSUUID.createUUID];

    [[[self.transportSession stub] andReturn:self.cookieStorage] cookieStorage];
    ZM_WEAK(self);
    [[self.transportSession stub] setAccessTokenRenewalFailureHandler:[OCMArg checkWithBlock:^BOOL(ZMCompletionHandlerBlock obj) {
        ZM_STRONG(self);
        self.authFailHandler = obj;
        return YES;
    }]];
    [[self.transportSession stub] setAccessTokenRenewalSuccessHandler:[OCMArg checkWithBlock:^BOOL(ZMAccessTokenHandlerBlock obj) {
        ZM_STRONG(self);
        self.tokenSuccessHandler = obj;
        return YES;
    }]];
    [[self.transportSession stub] setNetworkStateDelegate:OCMOCK_ANY];
    [[self.transportSession stub] enqueueOneTimeRequest:[OCMArg checkWithBlock:^BOOL(ZMTransportRequest *obj) {
        self.lastEnqueuedRequest = obj;
        return YES;
    }]];
    
    
    self.mockSessionManager = [[MockSessionManager alloc] init];
    self.mediaManager = [[MockMediaManager alloc] init];
    self.flowManagerMock = [[FlowManagerMock alloc] init];
    self.requestAvailableNotification = [OCMockObject mockForClass:ZMRequestAvailableNotification.class];
    
    self.clientRegistrationStatus = [[ZMClientRegistrationStatus alloc] initWithManagedObjectContext:self.syncMOC cookieStorage:self.cookieStorage registrationStatusDelegate:nil];
    self.proxiedRequestStatus = [[ProxiedRequestsStatus alloc] initWithRequestCancellation:self.transportSession];
    self.operationStatus = [[OperationStatus alloc] init];
    
    id applicationStatusDirectory = [OCMockObject niceMockForClass:[ApplicationStatusDirectory class]];
    [(ApplicationStatusDirectory *)[[(id)applicationStatusDirectory stub] andReturn:self.clientRegistrationStatus] clientRegistrationStatus];
    [(ApplicationStatusDirectory *)[[(id)applicationStatusDirectory stub] andReturn:self.proxiedRequestStatus] proxiedRequestStatus];
    [(ApplicationStatusDirectory *)[[(id)applicationStatusDirectory stub] andReturn:self.operationStatus] operationStatus];
    
    self.syncStrategy = [OCMockObject mockForClass:[ZMSyncStrategy class]];
    [(ZMSyncStrategy *)[[(id)self.syncStrategy stub] andReturn:applicationStatusDirectory] applicationStatusDirectory];
    [[(id)self.syncStrategy stub] didFinishSync];
    [self verifyMockLater:self.syncStrategy];

    self.operationLoop = [OCMockObject mockForClass:ZMOperationLoop.class];
    [[self.operationLoop stub] tearDown];
    [[[self.operationLoop stub] andReturn:self.syncStrategy] syncStrategy];
    
    self.storeProvider = [[MockLocalStoreProvider alloc] initWithSharedContainerDirectory:self.sharedContainerURL userIdentifier:self.userIdentifier contextDirectory:self.contextDirectory];
    
    self.sut = [[ZMUserSession alloc] initWithTransportSession:self.transportSession
                                                  mediaManager:self.mediaManager
                                                   flowManager:self.flowManagerMock
                                                     analytics:nil
                                                 operationLoop:self.operationLoop
                                                   application:self.application
                                                    appVersion:@"00000"
                                                 storeProvider:self.storeProvider];
        
    self.sut.thirdPartyServicesDelegate = self.thirdPartyServices;
    self.sut.sessionManager = self.mockSessionManager;
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    self.validCookie = [@"valid-cookie" dataUsingEncoding:NSUTF8StringEncoding];
    [self verifyMockLater:self.transportSession];
    [self verifyMockLater:self.syncStrategy];
    [self verifyMockLater:self.operationLoop];
}

- (void)tearDown
{
    [self.clientRegistrationStatus tearDown];
    self.clientRegistrationStatus = nil;
    self.proxiedRequestStatus = nil;
    self.operationStatus = nil;
    
    [self tearDownUserInfoObjectsOfMOC:self.syncMOC];
    [self.syncMOC.userInfo removeAllObjects];
    
    [self tearDownUserInfoObjectsOfMOC:self.uiMOC];
    [self.uiMOC.userInfo removeAllObjects];
    
    [super cleanUpAndVerify];
    NSURL *cachesURL = [[NSFileManager defaultManager] cachesURLForAccountWith:self.userIdentifier in:self.sut.sharedContainerURL];
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:cachesURL includingPropertiesForKeys:nil options:0 error:nil];
    for (NSURL *item in items) {
        [[NSFileManager defaultManager] removeItemAtURL:item error:nil];
    }
    
    self.storeProvider = nil;
    
    self.authFailHandler = nil;
    self.tokenSuccessHandler = nil;
    self.baseURL = nil;
    self.cookieStorage = nil;
    self.validCookie = nil;
    self.thirdPartyServices = nil;
    self.sut.thirdPartyServicesDelegate = nil;
    self.mockSessionManager = nil;

    [self.transportSession stopMocking];
    self.transportSession = nil;
    
    [self.operationLoop stopMocking];
    self.operationLoop = nil;
    
    [self.requestAvailableNotification stopMocking];
    self.requestAvailableNotification = nil;
    
    self.mediaManager = nil;
    
    self.flowManagerMock = nil;
    
    [(id)self.syncStrategy stopMocking];
    self.syncStrategy = nil;
    
    id tempSut = self.sut;
    self.sut = nil;
    [tempSut tearDown];
    
    [super tearDown];
}

- (void)didChangeAuthenticationData
{
    ++self.dataChangeNotificationsCount;
}

- (void)simulateLoggedInUser
{
    [self.syncMOC setPersistentStoreMetadata:@"foooooo" forKey:ZMPersistedClientIdKey];
    [ZMUser selfUserInContext:self.syncMOC].remoteIdentifier = [NSUUID createUUID];
    [self.cookieStorage setAuthenticationCookieData:self.validCookie];
}

@end
