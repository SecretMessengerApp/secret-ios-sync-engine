// 


@import WireTransport;
@import WireDataModel;

#import "MessagingTest.h"
#import "ZMClientRegistrationStatus.h"
#import "ZMCredentials.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>
#import "WireSyncEngine_iOS_Tests-Swift.h"
#import "ZMClientRegistrationStatus+Internal.h"
#import "NSError+ZMUserSession.h"

@interface FakeCredentialProfider : NSObject <ZMCredentialProvider>
@property (nonatomic) NSUInteger  clearCallCount;
@property (nonatomic) NSString *email;
@property (nonatomic) NSString *password;
@property (nonatomic) BOOL shouldReturnNilCredentials;
@end

@implementation FakeCredentialProfider

- (ZMEmailCredentials *)emailCredentials
{
    if (self.shouldReturnNilCredentials) {
        return nil;
    }
    NSString *email = self.email ?: @"knockknock@example.com";
    NSString *password = self.password ?: @"guessmeifyoucan";
    return [ZMEmailCredentials credentialsWithEmail:email password:password];
}

- (void)credentialsMayBeCleared
{
    self.clearCallCount++;
}

@end


@interface ZMClientRegistrationStatusTests : MessagingTest

@property (nonatomic) ZMClientRegistrationStatus *sut;
@property (nonatomic) id mockCookieStorage;
@property (nonatomic) id mockClientRegistrationDelegate;
@property (nonatomic) id sessionToken;
@property (nonatomic) PostLoginAuthenticationNotificationRecorder *authenticationNotificationRecorder;
@end



@implementation ZMClientRegistrationStatusTests

- (void)setUp {
    [super setUp];
    [self.uiMOC setPersistentStoreMetadata:nil forKey:ZMPersistedClientIdKey]; // make sure to call this before initializing sut
    self.mockCookieStorage = [OCMockObject niceMockForClass:[ZMPersistentCookieStorage class]];
    self.mockClientRegistrationDelegate = [OCMockObject niceMockForProtocol:@protocol(ZMClientRegistrationStatusDelegate)];
    [[[self.mockCookieStorage stub] andReturn:[NSData data]] authenticationCookieData];
    
    self.sut = [[ZMClientRegistrationStatus alloc] initWithManagedObjectContext:self.syncMOC
                                                                  cookieStorage:self.mockCookieStorage
                                                     registrationStatusDelegate:self.mockClientRegistrationDelegate];
    
    self.authenticationNotificationRecorder = [[PostLoginAuthenticationNotificationRecorder alloc] initWithManagedObjectContext:self.uiMOC];
}

- (void)tearDown
{
    self.authenticationNotificationRecorder = nil;
    self.mockCookieStorage = nil;
    [self.sut tearDown];
    self.sut = nil;
    
    [super tearDown];
}

- (NSError *)tooManyClientsError
{
    return [NSError errorWithDomain:@"ZMUserSession" code:ZMUserSessionCanNotRegisterMoreClients userInfo:nil];
}

- (NSError *)needToRegisterEmailError
{
    return [NSError errorWithDomain:@"ZMUserSession" code:ZMUserSessionNeedsToRegisterEmailToRegisterClient userInfo:nil];
}

- (void)testThatItInsertsANewClientIfThereIsNoneWaitingToBeSynced
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
    client.user = selfUser;
    client.remoteIdentifier = @"identifier";
    
    XCTAssertEqual(selfUser.clients.count, 1u);
    
    // when
    [self.sut prepareForClientRegistration];
    
    // then
    XCTAssertEqual(selfUser.clients.count, 2u);
}


- (void)testThatItDoesNotInsertANewClientIfThereIsAlreadyOneWaitingToBeSynced
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.uiMOC];
    client.user = selfUser;
    
    XCTAssertEqual(selfUser.clients.count, 1u);
    
    // when
    [self.sut prepareForClientRegistration];
    
    // then
    XCTAssertEqual(selfUser.clients.count, 1u);
}

- (void)testThatItReturns_WaitingForSelfUser_IFSelfUserDoesNotHaveRemoteID
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = nil;
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseWaitingForSelfUser);
}


- (void)testThatItReturns_Registered_IfSelfClientIsSet
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    [self.syncMOC setPersistentStoreMetadata:@"lala" forKey:ZMPersistedClientIdKey];
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseRegistered);
}

- (void)testThatItReturns_FetchingClients_WhenReceivingAnErrorWithTooManyClients
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    
    // when
    [self.sut didFailToRegisterClient:[self tooManyClientsError]];
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseFetchingClients);
}

- (void)testThatItReturns_WaitingForDeletion_AfterUserSelectedClientToDelete
{
    // given
    __block BOOL notificationReceived = NO;
    id postLoginToken = [[PostLoginAuthenticationObserverObjCToken alloc] initWithDispatchGroup:self.dispatchGroup handler:^(enum PostLoginAuthenticationEventObjC event, NSUUID *accountId, NSError *error) {
        NOT_USED(error);
        NOT_USED(accountId);
        
        if (event == PostLoginAuthenticationEventObjCAuthenticationInvalidated) {
            notificationReceived = YES;
        }
    }];
    
    [self performPretendingUiMocIsSyncMoc:^{
        ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
        selfUser.remoteIdentifier = NSUUID.createUUID;
        selfUser.emailAddress = @"email@domain.com";
        
        UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.uiMOC];
        client.remoteIdentifier = @"identifier";
        client.user = selfUser;
        
        [self.uiMOC setPersistentStoreMetadata:client.remoteIdentifier forKey:ZMPersistedClientIdKey];
        [self.uiMOC saveOrRollback];
        
        // when
        [self.sut didDetectCurrentClientDeletion];
    }];
    
    WaitForAllGroupsToBeEmpty(0.5);

    // then
    XCTAssertTrue(notificationReceived);
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseUnregistered);
    
    postLoginToken = nil;
}

- (void)testThatItResets_LocallyModifiedKeys_AfterUserSelectedClientToDelete
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = NSUUID.createUUID;
    
    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
    client.remoteIdentifier = @"identifier";
    client.user = selfUser;
    [client setLocallyModifiedKeys:[NSSet setWithObject:@"numberOfKeysRemaining"]];
    
    [self.syncMOC setPersistentStoreMetadata:client.remoteIdentifier forKey:ZMPersistedClientIdKey];
    
    // when
    [self.sut didDetectCurrentClientDeletion];
    
    // then
    XCTAssertFalse([client hasLocalModificationsForKey:@"numberOfKeysRemaining"]);
}

- (void)testThatItInvalidatesSelfClientAndDeletesAndRecreatesCryptoBoxOnDidDetectCurrentClientDeletion
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    selfUser.emailAddress = @"email@domain.com";
    
    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.uiMOC];
    client.user = selfUser;
    [self.uiMOC saveOrRollback];
    
    // when
    [self.sut didFailToRegisterClient:[self tooManyClientsError]];
    [ZMClientUpdateNotification notifyFetchingClientsCompletedWithUserClients:@[client] context:self.uiMOC];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseWaitingForDeletion);
}

- (void)testThatItReturnsYESForNeedsToRegisterClientIfNoClientIdInMetadata
{
    [self.uiMOC setPersistentStoreMetadata:nil forKey:ZMPersistedClientIdKey];
    XCTAssertTrue([ZMClientRegistrationStatus needsToRegisterClientInContext:self.uiMOC]);
}

- (void)testThatItReturnsNOForNeedsToRegisterClientIfThereIsClientIdInMetadata
{
    [self.uiMOC setPersistentStoreMetadata:@"lala" forKey:ZMPersistedClientIdKey];
    XCTAssertFalse([ZMClientRegistrationStatus needsToRegisterClientInContext:self.uiMOC]);
}

- (void)testThatItNotfiesCredentialProviderWhenClientIsRegistered
{
    //given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID new];

    //when
    [self.sut prepareForClientRegistration];

    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
    client.remoteIdentifier = [NSUUID createUUID].transportString;

    [self.sut didRegisterClient:client];

    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseRegistered);
}

- (void)testThatItNotfiesDelegateWhenClientIsRegistered
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = [NSUUID new];
    
    [self.sut prepareForClientRegistration];
    
    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.uiMOC];
    client.remoteIdentifier = [NSUUID createUUID].transportString;
    [[self.mockClientRegistrationDelegate expect] didRegisterUserClient:client];
    
    // when
    [self.sut didRegisterClient:client];
    
    // then
    [self.mockClientRegistrationDelegate verify];
}

- (void)testThatItTransitionsFrom_WaitingForEmail_To_Unregistered_WhenSelfUserChangesWithEmailAddress
{
    // given
    
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    selfUser.emailAddress = nil;
    selfUser.phoneNumber = nil;
    
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseWaitingForEmailVerfication);
    
    // when
    selfUser.emailAddress = @"me@example.com";
    [self.sut didFetchSelfUser];
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseUnregistered);
}


- (void)testThatItDoesNotTransitionsFrom_WaitingForEmail_To_Unregistered_WhenSelfUserChangesWithoutEmailAddress
{
    // given
    
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    selfUser.emailAddress = nil;
    selfUser.phoneNumber = nil;
    
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseWaitingForEmailVerfication);
    
    // when
    selfUser.emailAddress = nil;
    [self.sut didFetchSelfUser];
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseWaitingForEmailVerfication);
}

- (void)testThatItResetsThePhaseToWaitingForLoginIfItNeedsPasswordToRegisterClient
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    selfUser.emailAddress = @"email@domain.com";
    [[[self.mockCookieStorage stub] andReturn:[NSData data]] authenticationCookieData];
    self.sut.emailCredentials = nil;
    
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseUnregistered);

    NSError *error = [NSError errorWithDomain:@"ZMUserSession" code:ZMUserSessionNeedsPasswordToRegisterClient userInfo:nil];

    // when
    [self.sut didFailToRegisterClient:error];
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseWaitingForLogin);
    
    // and when
    // the user entered the password, we can proceed trying to register the client
    self.sut.emailCredentials = [ZMEmailCredentials credentialsWithEmail:@"john.doe@domain.com" password:@"12345789"];
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseUnregistered);
}

- (void)testThatItDoesNotRequireEmailRegistrationForTeamUser
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    selfUser.emailAddress = nil;
    selfUser.phoneNumber = nil;
    selfUser.usesCompanyLogin = YES;
    
    // then
    XCTAssertEqual(self.sut.currentPhase, ZMClientRegistrationPhaseUnregistered);
}

@end



@implementation ZMClientRegistrationStatusTests (AuthenticationNotifications)

- (void)testThatItNotifiesTheUIAboutSuccessfulRegistration
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = self.userIdentifier;
    [self.uiMOC saveOrRollback];
    
    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.uiMOC];
    client.remoteIdentifier = @"yay";
    
    // when
    [self.sut didRegisterClient:client];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.authenticationNotificationRecorder.notifications.count, 1u);
    PostLoginAuthenticationNotificationEvent *note = self.authenticationNotificationRecorder.notifications.firstObject;
    XCTAssertEqual(note.event, PostLoginAuthenticationEventObjCClientRegistrationDidSucceed);
}

- (void)testThatItNotifiesTheUIIfTheClientWasAlreadyRegisteredBeforeFetchingTheSelfUser // TODO jacob rename (we no longer send this notification)
{
    // given
    [self.syncMOC setPersistentStoreMetadata:@"brrrrr" forKey:ZMPersistedClientIdKey];
    
    // when
    [self.sut didFetchSelfUser];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.authenticationNotificationRecorder.notifications.count, 0u);
}

- (void)testThatItNotifiesTheUIIfTheRegistrationFailsWithMissingEmailVerification
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    selfUser.emailAddress = nil;
    selfUser.phoneNumber = nil;
    [self.uiMOC saveOrRollback];
    
    // when
    [self.sut didFetchSelfUser];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.authenticationNotificationRecorder.notifications.count, 1u);
    PostLoginAuthenticationNotificationEvent *note = self.authenticationNotificationRecorder.notifications.firstObject;
    XCTAssertEqual(note.event, PostLoginAuthenticationEventObjCClientRegistrationDidFail);
    XCTAssertEqual(note.error.code, [self needToRegisterEmailError].code);
}

- (void)testThatItNotifiesTheUIIfTheRegistrationFailsWithMissingPasswordError
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = self.userIdentifier;
    [self.uiMOC saveOrRollback];
    
    NSError *error = [NSError errorWithDomain:@"ZMUserSession" code:ZMUserSessionNeedsPasswordToRegisterClient userInfo:nil];
    
    // when
    [self.sut didFailToRegisterClient:error];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.authenticationNotificationRecorder.notifications.count, 1u);
    PostLoginAuthenticationNotificationEvent *note = self.authenticationNotificationRecorder.notifications.firstObject;
    XCTAssertEqual(note.event, PostLoginAuthenticationEventObjCClientRegistrationDidFail);
    XCTAssertEqual(note.error.code, error.code);
}

- (void)testThatItNotifiesTheUIIfTheRegistrationFailsWithWrongCredentialsError
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = self.userIdentifier;
    [self.uiMOC saveOrRollback];
    
    NSError *error = [NSError errorWithDomain:@"ZMUserSession" code:ZMUserSessionInvalidCredentials userInfo:nil];
    
    // when
    [self.sut didFailToRegisterClient:error];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.authenticationNotificationRecorder.notifications.count, 1u);
    PostLoginAuthenticationNotificationEvent *note = self.authenticationNotificationRecorder.notifications.firstObject;
    XCTAssertEqual(note.event, PostLoginAuthenticationEventObjCClientRegistrationDidFail);
    XCTAssertEqual(note.error.code, error.code);
}

- (void)testThatItDoesNotNotifiesTheUIIfTheRegistrationFailsWithTooManyClientsError
{
    // given
    NSError *error = [self tooManyClientsError];
    
    // when
    [self.sut didFailToRegisterClient:error];
    
    // then
    XCTAssertEqual(self.authenticationNotificationRecorder.notifications.count, 0u);
}

- (void)testThatItDeletesTheCookieIfFetchingClientsFailedWithError_SelfClientIsInvalid
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
    selfUser.remoteIdentifier = [NSUUID UUID];
    
    UserClient *client = [UserClient insertNewObjectInManagedObjectContext:self.syncMOC];
    client.user = selfUser;
    client.remoteIdentifier = @"identifer";
    [self.syncMOC saveOrRollback];
    [self.syncMOC setPersistentStoreMetadata:client.remoteIdentifier forKey:ZMPersistedClientIdKey];

    XCTAssertNotNil(selfUser.selfClient);
    
    NSError *error = [NSError errorWithDomain:@"ClientManagement" code:ClientUpdateErrorSelfClientIsInvalid userInfo:nil];

    // expect
    [[self.mockCookieStorage expect] deleteKeychainItems];
    
    // when
    [ZMClientUpdateNotification notifyFetchingClientsDidFailWithError:error context:self.uiMOC];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertNil([self.syncMOC persistentStoreMetadataForKey:ZMPersistedClientIdKey]);
    [self.mockCookieStorage verify];
}


@end

