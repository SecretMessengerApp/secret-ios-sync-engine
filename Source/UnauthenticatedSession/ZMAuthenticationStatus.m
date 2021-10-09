// 


@import WireTransport;
@import WireUtilities;
@import WireDataModel;

#import "ZMAuthenticationStatus.h"
#import "ZMCredentials+Internal.h"
#import "NSError+ZMUserSession.h"
#import "NSError+ZMUserSessionInternal.h"
#import "ZMUserSessionRegistrationNotification.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>
#import "ZMAuthenticationStatus_Internal.h"


static NSString *const TimerInfoOriginalCredentialsKey = @"credentials";
static NSString *const AuthenticationCenterDataChangeNotificationName = @"ZMAuthenticationStatusDataChangeNotificationName";
NSTimeInterval DebugLoginFailureTimerOverride = 0;

static NSString* ZMLogTag ZM_UNUSED = @"Authentication";

@interface ZMAuthenticationStatus ()

@property (nonatomic, weak) id<UserInfoParser> userInfoParser;
@property (nonatomic, strong) UserInfo *authenticatedUserInfo;

@end

@implementation ZMAuthenticationStatus

- (instancetype)initWithGroupQueue:(id<ZMSGroupQueue>)groupQueue userInfoParser:(nullable id<UserInfoParser>)userInfoParser {
    self = [super init];
    if(self) {
        self.groupQueue = groupQueue;
        self.isWaitingForLogin = !self.isLoggedIn;
        self.userInfoParser = userInfoParser;
    }
    return self;
}

- (void)dealloc
{
    [self stopLoginTimer];
}

- (ZMCredentials *)loginCredentials
{
    return self.internalLoginCredentials;
}

- (NSUUID *)authenticatedUserIdentifier
{
    if (self.authenticatedUserInfo != nil) {
        return self.authenticatedUserInfo.identifier;
    }
    return nil;
}

- (void)resetLoginAndRegistrationStatus
{
    [self stopLoginTimer];
    
    self.registrationPhoneNumberThatNeedsAValidationCode = nil;
    self.loginPhoneNumberThatNeedsAValidationCode = nil;

    self.internalLoginCredentials = nil;
    self.registrationPhoneValidationCredentials = nil;

    self.isWaitingForEmailVerification = NO;
    self.isWaitingForBackupImport = NO;
}

- (void)setLoginCredentials:(ZMCredentials *)credentials
{
    if(credentials != self.internalLoginCredentials) {
        self.internalLoginCredentials = credentials;
        [ZMPersistentCookieStorage setCookiesPolicy:NSHTTPCookieAcceptPolicyAlways];
        [[[NotificationInContext alloc] initWithName:AuthenticationCenterDataChangeNotificationName
                                             context:self object:nil userInfo:nil] post];
    }
}

- (id)addAuthenticationCenterObserver:(id<ZMAuthenticationStatusObserver>)observer;
{
    ZM_WEAK(observer);
    return [NotificationInContext addObserverWithName:AuthenticationCenterDataChangeNotificationName
                                       context:self
                                        object:nil
                                         queue:nil
                                         using:^(NotificationInContext * notification __unused) {
                                             ZM_STRONG(observer);
                                             [observer didChangeAuthenticationData];
     }];
}

- (ZMAuthenticationPhase)currentPhase
{
    if(self.isLoggedIn) {
        return ZMAuthenticationPhaseAuthenticated;
    }
    if(self.isWaitingForBackupImport) {
        return ZMAuthenticationPhaseWaitingToImportBackup;
    }
    if(self.internalLoginCredentials.credentialWithEmail && self.isWaitingForLogin) {
        return ZMAuthenticationPhaseLoginWithEmail;
    }
    if(self.internalLoginCredentials.credentialWithPhone && self.isWaitingForLogin) {
        return ZMAuthenticationPhaseLoginWithPhone;
    }
    if(self.loginPhoneNumberThatNeedsAValidationCode != nil) {
        return ZMAuthenticationPhaseRequestPhoneVerificationCodeForLogin;
    }
    return ZMAuthenticationPhaseUnauthenticated;
}

- (BOOL)needsCredentialsToLogin
{
    return !self.isLoggedIn && self.loginCredentials == nil;
}

- (BOOL)isLoggedIn
{
    return nil != self.authenticationCookieData;
}

- (void)startLoginTimer
{
    [self stopLoginTimer];
    self.loginTimer = [ZMTimer timerWithTarget:self];
    self.loginTimer.userInfo = @{ TimerInfoOriginalCredentialsKey : self.loginCredentials };
    [self.loginTimer fireAfterTimeInterval:(DebugLoginFailureTimerOverride > 0 ?: 60 )];
}

- (void)stopLoginTimer
{
    [self.loginTimer cancel];
    self.loginTimer = nil;
}

- (void)timerDidFire:(ZMTimer *)timer
{
    [self.groupQueue performGroupedBlock:^{
        [self didTimeoutLoginForCredentials:timer.userInfo[TimerInfoOriginalCredentialsKey]];
    }];
}

- (void)prepareForLoginWithCredentials:(ZMCredentials *)credentials
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    self.authenticationCookieData = nil;
    [self resetLoginAndRegistrationStatus];
    self.loginCredentials = credentials;
    self.isWaitingForLogin = YES;
    [self startLoginTimer];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)continueAfterBackupImportStep
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    [self continueAuthenticationWithUserInfo:self.authenticatedUserInfo];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)continueAuthenticationWithResponse:(ZMTransportResponse *)response
{
    [self continueAuthenticationWithUserInfo:response.extractUserInfo];
}

- (void)continueAuthenticationWithUserInfo:(UserInfo *)userInfo
{
    self.isWaitingForBackupImport = NO;
    if (self.isWaitingForLogin) {
        self.isWaitingForLogin = NO;
    }
    [self notifyAuthenticationDidSucceed];
    // There might be some authentication errors after parsing the response (e.g. too many accounts)
    
    [self.userInfoParser upgradeToAuthenticatedSessionWithUserInfo:userInfo];
}

- (void)prepareForRequestingPhoneVerificationCodeForRegistration:(NSString *)phone
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self resetLoginAndRegistrationStatus];
    self.registrationPhoneNumberThatNeedsAValidationCode = [ZMPhoneNumberValidator validatePhoneNumber: phone];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)prepareForRequestingPhoneVerificationCodeForLogin:(NSString *)phone;
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self resetLoginAndRegistrationStatus];
    self.loginPhoneNumberThatNeedsAValidationCode = [ZMPhoneNumberValidator validatePhoneNumber: phone];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didTimeoutLoginForCredentials:(ZMCredentials *)credentials
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    if((self.currentPhase == ZMAuthenticationPhaseLoginWithEmail || self.currentPhase == ZMAuthenticationPhaseLoginWithPhone)
       && self.loginCredentials == credentials)
    {
        self.loginCredentials = nil;
        [self notifyAuthenticationDidFail:[NSError userSessionErrorWithErrorCode:ZMUserSessionNetworkError userInfo:nil]];
    }
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didCompletePhoneVerificationSuccessfully
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self resetLoginAndRegistrationStatus];
    [ZMUserSessionRegistrationNotification notifyPhoneNumberVerificationDidSucceedInContext:self];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didFailPhoneVerificationForRegistration:(NSError *)error
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self resetLoginAndRegistrationStatus];
    [ZMUserSessionRegistrationNotification notifyPhoneNumberVerificationDidFail:error context:self];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)loginSucceededWithResponse:(ZMTransportResponse *)response
{
    [self loginSucceededWithUserInfo:response.extractUserInfo];
}

- (void)loginSucceededWithUserInfo:(UserInfo *)userInfo
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (self.completedRegistration) {
        [self continueAuthenticationWithUserInfo:userInfo];
    } else {
        self.authenticatedUserInfo = userInfo;
        self.isWaitingForBackupImport = YES;
        BOOL existingAccount = [self.userInfoParser accountExistsLocallyFromUserInfo:userInfo];
        [self notifyAuthenticationReadyToImportBackupWithExistingAccount:existingAccount];
    }
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didFailLoginWithPhone:(BOOL)invalidCredentials
{
    ZMLogDebug(@"%@ invalid credentials: %d", NSStringFromSelector(_cmd), invalidCredentials);
    [self resetLoginAndRegistrationStatus];
    
    NSError *error = [NSError userSessionErrorWithErrorCode:(invalidCredentials ? ZMUserSessionInvalidCredentials : ZMUserSessionUnknownError) userInfo:nil];
    [self notifyAuthenticationDidFail:error];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didFailLoginWithEmail:(BOOL)invalidCredentials
{
    ZMLogDebug(@"%@ invalid credentials: %d", NSStringFromSelector(_cmd), invalidCredentials);
    
    NSError *error = [NSError userSessionErrorWithErrorCode:(invalidCredentials ? ZMUserSessionInvalidCredentials : ZMUserSessionUnknownError) userInfo:nil];
    [self notifyAuthenticationDidFail:error];
    [self resetLoginAndRegistrationStatus];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didFailLoginWithEmailBecausePendingValidation
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    self.isWaitingForEmailVerification = YES;
    NSError *error = [NSError userSessionErrorWithErrorCode:ZMUserSessionAccountIsPendingActivation userInfo:nil];
    [self notifyAuthenticationDidFail:error];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didFailLoginBecauseAccountSuspended
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error = [NSError userSessionErrorWithErrorCode:ZMUserSessionAccountSuspended userInfo:nil];
    [self notifyAuthenticationDidFail:error];
    [self resetLoginAndRegistrationStatus];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)cancelWaitingForEmailVerification
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self resetLoginAndRegistrationStatus];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didCompleteRequestForPhoneRegistrationCodeSuccessfully;
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    self.registrationPhoneNumberThatNeedsAValidationCode = nil;
    [ZMUserSessionRegistrationNotification notifyPhoneNumberVerificationCodeRequestDidSucceedInContext:self];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)setAuthenticationCookieData:(NSData *)data;
{
    ZMLogDebug(@"Setting cookie data: %@", @(data.length));
    _authenticationCookieData = data;
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didCompleteRequestForLoginCodeSuccessfully
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self notifyLoginCodeRequestDidSucceed];
    self.loginPhoneNumberThatNeedsAValidationCode = nil;
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

- (void)didFailRequestForLoginCode:(NSError *)error;
{
    ZMLogDebug(@"%@", NSStringFromSelector(_cmd));
    self.loginPhoneNumberThatNeedsAValidationCode = nil;
    [self notifyLoginCodeRequestDidFail:error];
    ZMLogDebug(@"current phase: %lu", (unsigned long)self.currentPhase);
}

@end


@implementation ZMAuthenticationStatus (CredentialProvider)

- (void)credentialsMayBeCleared
{
    if (self.currentPhase == ZMAuthenticationPhaseAuthenticated) {
        [self resetLoginAndRegistrationStatus];
    }
}

- (ZMEmailCredentials *)emailCredentials
{
    if (self.loginCredentials.credentialWithEmail) {
        ZMEmailCredentials *credentials = [ZMEmailCredentials credentialsWithEmail:self.loginCredentials.email
                                               password:self.loginCredentials.password];
        credentials.token = self.loginCredentials.token;
        return  credentials;
    }
    return nil;
}

@end

