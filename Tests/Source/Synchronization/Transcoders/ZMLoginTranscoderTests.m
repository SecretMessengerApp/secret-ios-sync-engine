// 

@import WireDataModel;

#import "MessagingTest.h"
#import "ZMLoginTranscoder+Internal.h"
#import "ZMUserSession+Internal.h"
#import "ZMCredentials.h"
#import "ZMAuthenticationStatus.h"
#import "NSError+ZMUserSession.h"
#import "ZMUserSessionRegistrationNotification.h"
#import "ZMClientRegistrationStatus.h"
#import "ZMAuthenticationStatus.h"
#import "ZMAuthenticationStatus_Internal.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"


@import WireUtilities;

static NSString * const TestEmail = @"bar@example.com";
static NSString * const TestPassword = @"super-secure-password-sijovhjs987y";

static NSString * const TestPhoneNumber = @"+7123456789";
static NSString * const TestPhoneCode = @"123456";

extern NSTimeInterval DefaultPendingValidationLoginAttemptInterval;

@interface TestTimedSingleRequest : NSObject

@property (nonatomic) NSTimeInterval timeInterval;
- (ZMTransportRequest *)nextRequest;

@end



@implementation TestTimedSingleRequest

- (ZMTransportRequest *)nextRequest {
    return nil;
}

@end

@interface ZMLoginTranscoderTests : MessagingTest

@property (nonatomic) DispatchGroupQueue *groupQueue;
@property (nonatomic) ZMLoginTranscoder *sut;
@property (nonatomic) ZMAuthenticationStatus *authenticationStatus;
@property (nonatomic) id mockClientRegistrationStatus;
@property (nonatomic) id mockApplicationStatusDirectory;

@property (nonatomic) ZMCredentials *testEmailCredentials;
@property (nonatomic) ZMCredentials *testPhoneNumberCredentials;
@property (nonatomic) NSTimeInterval originalLoginTimerInterval;
@property (nonatomic) id mockLocale;
@property (nonatomic) MockUserInfoParser *mockUserInfoParser;

@end

@implementation ZMLoginTranscoderTests


- (void)setUp {
    [super setUp];

    self.mockUserInfoParser = [[MockUserInfoParser alloc] init];

    self.groupQueue = [[DispatchGroupQueue alloc] initWithQueue:dispatch_get_main_queue()];
    self.originalLoginTimerInterval = DefaultPendingValidationLoginAttemptInterval;
    self.authenticationStatus = [[ZMAuthenticationStatus alloc] initWithGroupQueue:self.groupQueue userInfoParser:self.mockUserInfoParser];

    self.mockClientRegistrationStatus = [OCMockObject niceMockForClass:[ZMClientRegistrationStatus class]];
    
    self.mockLocale = [OCMockObject niceMockForClass:[NSLocale class]];
    [[[self.mockLocale stub] andReturn:[NSLocale localeWithLocaleIdentifier:@"fr_FR"]] currentLocale];


    self.sut = [[ZMLoginTranscoder alloc] initWithGroupQueue:self.groupQueue
                                        authenticationStatus:self.authenticationStatus];
    
    self.testEmailCredentials = [ZMEmailCredentials credentialsWithEmail:TestEmail password:TestPassword];
    self.testPhoneNumberCredentials = [ZMPhoneCredentials credentialsWithPhoneNumber:TestPhoneNumber verificationCode:TestPhoneCode];
}

- (void)tearDown {
    [self.sut tearDown];
    self.groupQueue = nil;
    self.sut = nil;
    self.authenticationStatus = nil;
    self.mockClientRegistrationStatus = nil;
    self.mockLocale = nil;
    self.mockUserInfoParser = nil;
    DefaultPendingValidationLoginAttemptInterval = self.originalLoginTimerInterval;
    [super tearDown];
}

- (void)testThatItCreatesTheTimedRequestSyncWithZeroDelayInDefaultConstructor
{
    // given
    ZMLoginTranscoder *sut = [[ZMLoginTranscoder alloc] initWithGroupQueue:self.groupQueue authenticationStatus:self.authenticationStatus];
    
    // then
    XCTAssertNotNil(sut.timedDownstreamSync);
    XCTAssertEqualObjects(sut.timedDownstreamSync.groupQueue, self.groupQueue);
    XCTAssertEqualObjects(sut.timedDownstreamSync.transcoder, sut);
    XCTAssertEqual(sut.timedDownstreamSync.timeInterval, 0);
    
    // after
    [sut tearDown];
}

- (void)expectAuthenticationSucceedAfter:(void(^)(void))block;
{
    id mockAuthStatus = [OCMockObject partialMockForObject:self.authenticationStatus];
    [[[mockAuthStatus expect] andForwardToRealObject] loginSucceededWithResponse:OCMOCK_ANY];
    
    // when
    block();
    
    //then
    [mockAuthStatus verify];
}

- (void)expectAuthenticationFailedWithError:(ZMUserSessionErrorCode)code after:(void(^)(void))block;
{
    //expect
    __block BOOL notified = NO;
    id token = [[PreLoginAuthenticationObserverToken alloc] initWithAuthenticationStatus:self.authenticationStatus handler:^(enum PreLoginAuthenticationEventObjc event, NSError *error) {
        XCTAssertEqual(event, PreLoginAuthenticationEventObjcAuthenticationDidFail);
        XCTAssertNotNil(error);
        XCTAssertEqual((ZMUserSessionErrorCode)error.code, code);
        notified = YES;
    }];
    
    // when
    block();
    WaitForAllGroupsToBeEmpty(0.5);
    
    //then
    XCTAssert(notified);
    token = nil;
//    [ZMUserSessionAuthenticationNotification removeObserverForToken:token];
}

- (void)expectRegistrationSucceedAfter:(void(^)(void))block;
{
    //expect
    __block BOOL notified = NO;
    id token = [ZMUserSessionRegistrationNotification addObserverInContext:self.authenticationStatus withBlock:^(ZMUserSessionRegistrationNotificationType event, NSError *error) {
        NOT_USED(event);
        XCTAssertNil(error);
        notified = YES;
    }];
    
    // when
    block();
    
    //then
    XCTAssert(notified);
    token = nil;
}

- (void)expectRegistrationFailedWithError:(ZMUserSessionErrorCode)code after:(void(^)(void))block;
{
    //expect
    __block BOOL notified = NO;
    id token = [ZMUserSessionRegistrationNotification addObserverInContext:self.authenticationStatus withBlock:^(ZMUserSessionRegistrationNotificationType event, NSError *error) {
        NOT_USED(event);
        XCTAssertNotNil(error);
        XCTAssertEqual((ZMUserSessionErrorCode)error.code, code);
        notified = YES;
    }];
    
    // when
    block();
    
    //then
    XCTAssert(notified);
    token = nil;
}

@end

@implementation ZMLoginTranscoderTests (Login)

- (void)testThatItReturnsNoLoginRequestWhenTheUserSessionHasNoCredentials
{
    // when
    ZMTransportRequest *request = [self.sut nextRequest];
    
    // then
    XCTAssertNil(request);
}


- (void)testThatItGeneratesALoginRequestWhenTheUserSessionHasCredentialsWithEmailAndWeAreNotLoggedIn
{
    // given
    NSDictionary *payload = @{@"email": self.testEmailCredentials.email,
                              @"password": self.testEmailCredentials.password,
                              @"label": CookieLabel.current.value};
    ZMTransportRequest *expectedRequest = [[ZMTransportRequest alloc] initWithPath:ZMLoginURL method:ZMMethodPOST payload:payload authentication:ZMTransportRequestAuthCreatesCookieAndAccessToken];
    
    [self.authenticationStatus prepareForLoginWithCredentials:self.testEmailCredentials];

    // when
    ZMTransportRequest *request = [self.sut nextRequest];
    
    // then
    XCTAssertEqualObjects(request, expectedRequest);
}

- (void)testThatItGeneratesALoginRequestWhenTheUserSessionHasCredentialsWithPhoneNumberAndWeAreNotLoggedIn
{
    // given
    NSDictionary *payload = @{@"phone": self.testPhoneNumberCredentials.phoneNumber,
                              @"code": self.testPhoneNumberCredentials.phoneNumberVerificationCode,
                              @"label": CookieLabel.current.value};
    ZMTransportRequest *expectedRequest = [[ZMTransportRequest alloc] initWithPath:ZMLoginURL method:ZMMethodPOST payload:payload authentication:ZMTransportRequestAuthCreatesCookieAndAccessToken];
    [self.authenticationStatus prepareForLoginWithCredentials:self.testPhoneNumberCredentials];
    
    // when
    ZMTransportRequest *request = [self.sut nextRequest];
    
    // then
    XCTAssertEqualObjects(request, expectedRequest);
}

- (void)testThatItDoesNotGenerateALoginRequestWhenTheUserSessionHasNoCredentials
{
    // when
    ZMTransportRequest *request = [self.sut nextRequest];
    
    // then
    XCTAssertNil(request);
}

- (void)testThatItDoesNotGenerateALoginRequestWhenTheUserSessionIsLoggedIn
{
    // given
    [self.authenticationStatus setAuthenticationCookieData:[@"foo" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // when
    ZMTransportRequest *request = [self.sut nextRequest];
    
    // then
    XCTAssertNil(request);
}


@end


@implementation  ZMLoginTranscoderTests (AuthenticationDelegate)

-(void)testThatItCallsAuthenticationSucceededOnLoginSucceedsWithEmail
{
    // given
    NSDictionary *content = @{@"access_token": @"61184561417968870ce708ed0c319206914bc56db444d01227a63f9b9849045f.1.1401213378.a.3bc5750a-b965-40f8-aff2-831e9b5ac2e9.846754296078244309",
                              @"expires_in": @604800,
                              @"token_type": @"Bearer"
                              };
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMEmailCredentials credentialsWithEmail:@"foo@example.com" password:@"12345678"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:200 transportSessionError:nil];
    
    // when
    
    [self expectAuthenticationSucceedAfter:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}

-(void)testThatItCallsAuthenticationSucceededOnLoginSucceedsWithPhoneNumber
{
    // given
    NSDictionary *content = @{@"access_token": @"61184561417968870ce708ed0c319206914bc56db444d01227a63f9b9849045f.1.1401213378.a.3bc5750a-b965-40f8-aff2-831e9b5ac2e9.846754296078244309",
                              @"expires_in": @604800,
                              @"token_type": @"Bearer"
                              };
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMPhoneCredentials credentialsWithPhoneNumber:@"+49123456789" verificationCode:@"123456"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:200 transportSessionError:nil];

    // when
    [self expectAuthenticationSucceedAfter:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}

-(void)testThatItCallsAuthenticationFailOnInvalidEmailCredentialsIfNotDuplicatedEmailRegistered
{
    // given
    NSDictionary *content = @{@"code":@403,
                              @"message":@"Invalid login credentials",
                              @"label":@"invalid-credentials"};
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMEmailCredentials credentialsWithEmail:@"foo@example.com" password:@"12345678"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:403 transportSessionError:nil];
    
    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionInvalidCredentials after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}

-(void)testThatItCallsRegistrationFailOnInvalidPhoneNumberCredentialsIfNotDuplicatedPhoneNumberRegistered
{
    // given
    NSDictionary *content = @{@"code":@403,
                              @"message":@"Invalid login credentials",
                              @"label":@"invalid-credentials"};
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:403 transportSessionError:nil];
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMPhoneCredentials credentialsWithPhoneNumber:@"+4912345678" verificationCode:@"123456"]];
    
    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionInvalidCredentials after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}

-(void)testThatItCallsAuthenticationFailOnErrorResponseWithoutPayload
{
    // given
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMPhoneCredentials credentialsWithPhoneNumber:@"+4912345678" verificationCode:@"123456"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:nil HTTPStatus:403 transportSessionError:nil];

    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionUnknownError after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}

-(void)testThatItCallsAuthenticationFailOnPendingActivation
{
    // given
    NSDictionary *content = @{@"code":@403,
                              @"message":@"Account pending activation",
                              @"label":@"pending-activation"};
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMEmailCredentials credentialsWithEmail:@"foo@example.com" password:@"12345678"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:403 transportSessionError:nil];
    
    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionAccountIsPendingActivation after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}

- (void)testThatItCallsAuthenticationFailOnPhoneLoginWithSuspendedAccount
{
    // given
    NSDictionary *content = @{@"code":@403,
                              @"message":@"Account suspended.",
                              @"label":@"suspended"};
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMPhoneCredentials credentialsWithPhoneNumber:@"+4912345678" verificationCode:@"123456"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:403 transportSessionError:nil];
    
    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionAccountSuspended after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}


- (void)testThatItCallsAuthenticationFailOnEmailLoginWithSuspendedAccount
{
    // given
    NSDictionary *content = @{@"code":@403,
                              @"message":@"Account suspended.",
                              @"label":@"suspended"};
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMEmailCredentials credentialsWithEmail:@"foo@example.com" password:@"12345678"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:403 transportSessionError:nil];
    
    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionAccountSuspended after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
}

-(void)testThatItInvalidatesTheCredentialsOnLoginErrorWhenLoggingWithEmail
{
    // given
    NSDictionary *content = @{@"code":@403,
                              @"message":@"Invalid login credentials",
                              @"label":@"invalid-credentials"};
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:403 transportSessionError:nil];
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMEmailCredentials credentialsWithEmail:@"foo@example.com" password:@"12345678"]];
    
    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionInvalidCredentials after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
    
    // then
    XCTAssertEqual(self.authenticationStatus.currentPhase, ZMAuthenticationPhaseUnauthenticated);
    XCTAssertNil(self.authenticationStatus.loginCredentials);

}

-(void)testThatItInvalidatesTheCredentialsOnLoginErrorWhenLoggingWithPhoneNumber
{
    // given
    NSDictionary *content = @{@"code":@403,
                              @"message":@"Invalid login credentials",
                              @"label":@"invalid-credentials"};
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMPhoneCredentials credentialsWithPhoneNumber:@"+49123456789" verificationCode:@"12345678"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:403 transportSessionError:nil];
    
    // when
    [self expectAuthenticationFailedWithError:ZMUserSessionInvalidCredentials after:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
    
    // then
    XCTAssertEqual(self.authenticationStatus.currentPhase, ZMAuthenticationPhaseUnauthenticated);
    XCTAssertNil(self.authenticationStatus.loginCredentials);
}

- (void)testThatItDoesNotDeleteCredentialsButSwitchesToStateAuthenticatedOnLoginSucceedsWithPhone
{
    // given
    NSDictionary *content = @{@"access_token": @"61184561417968870ce708ed0c319206914bc56db444d01227a63f9b9849045f.1.1401213378.a.3bc5750a-b965-40f8-aff2-831e9b5ac2e9.846754296078244309",
                              @"expires_in": @604800,
                              @"token_type": @"Bearer"
                              };
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMPhoneCredentials credentialsWithPhoneNumber:@"+49123456789" verificationCode:@"12345678"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:200 transportSessionError:nil];
    
    // when
    [self expectAuthenticationSucceedAfter:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
        [self.authenticationStatus continueAfterBackupImportStep];
        [self.authenticationStatus setAuthenticationCookieData:[@"foo" dataUsingEncoding:NSUTF8StringEncoding]];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
    
    // then
    XCTAssertEqual(self.authenticationStatus.currentPhase, ZMAuthenticationPhaseAuthenticated);
    XCTAssertNotNil(self.authenticationStatus.loginCredentials);

}

- (void)testThatItDoesNotDeleteCredentialsButSwitchesToStateAuthenticatedOnLoginSucceedsWithEmail
{
    // given
    NSDictionary *content = @{@"access_token": @"61184561417968870ce708ed0c319206914bc56db444d01227a63f9b9849045f.1.1401213378.a.3bc5750a-b965-40f8-aff2-831e9b5ac2e9.846754296078244309",
                              @"expires_in": @604800,
                              @"token_type": @"Bearer"
                              };
    [self.authenticationStatus prepareForLoginWithCredentials:[ZMEmailCredentials credentialsWithEmail:@"foo@example.com" password:@"12345678"]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:content HTTPStatus:200 transportSessionError:nil];
    
    // when
    [self expectAuthenticationSucceedAfter:^{
        [[self.sut nextRequest] completeWithResponse:response];
        WaitForAllGroupsToBeEmpty(0.5);
        [self.authenticationStatus continueAfterBackupImportStep];
        [self.authenticationStatus setAuthenticationCookieData:[@"foo" dataUsingEncoding:NSUTF8StringEncoding]];
        WaitForAllGroupsToBeEmpty(0.5);
    }];
    
    // then
    XCTAssertEqual(self.authenticationStatus.currentPhase, ZMAuthenticationPhaseAuthenticated);
    XCTAssertNotNil(self.authenticationStatus.loginCredentials);

}

@end
