// 


@import Foundation;
@import CoreData;

#import "NSError+ZMUserSession.h"
#import "ZMUserSession+Authentication.h"
#import "ZMClientRegistrationStatus+Internal.h"

@class UserInfo;
@class ZMCredentials;
@class ZMEmailCredentials;
@class ZMPhoneCredentials;
@class ZMPersistentCookieStorage;
@class ZMClientRegistrationStatus;
@class ZMTransportResponse;
@protocol UserInfoParser;

FOUNDATION_EXPORT NSTimeInterval DebugLoginFailureTimerOverride;

/// Invoked when the credentials are changed
@protocol ZMAuthenticationStatusObserver <NSObject>
- (void)didChangeAuthenticationData;
@end


typedef NS_ENUM(NSUInteger, ZMAuthenticationPhase) {
    ZMAuthenticationPhaseUnauthenticated = 0,
    ZMAuthenticationPhaseLoginWithPhone,
    ZMAuthenticationPhaseLoginWithEmail,
    ZMAuthenticationPhaseWaitingToImportBackup,
    ZMAuthenticationPhaseRequestPhoneVerificationCodeForLogin,
    ZMAuthenticationPhaseVerifyPhone,
    ZMAuthenticationPhaseAuthenticated
};

@interface ZMAuthenticationStatus : NSObject

@property (nonatomic, readonly, copy) NSString *registrationPhoneNumberThatNeedsAValidationCode;
@property (nonatomic, readonly, copy) NSString *loginPhoneNumberThatNeedsAValidationCode;

@property (nonatomic, readonly) ZMCredentials *loginCredentials;
@property (nonatomic, readonly) ZMPhoneCredentials *registrationPhoneValidationCredentials;

@property (nonatomic, readonly) BOOL isWaitingForBackupImport;
@property (nonatomic, readonly) BOOL completedRegistration;
@property (nonatomic, readonly) BOOL needsCredentialsToLogin;

@property (nonatomic, readonly) ZMAuthenticationPhase currentPhase;
@property (nonatomic, readonly) NSUUID *authenticatedUserIdentifier;
@property (nonatomic) NSData *profileImageData;

@property (nonatomic) NSData *authenticationCookieData;

- (instancetype)initWithGroupQueue:(id<ZMSGroupQueue>)groupQueue userInfoParser:(id<UserInfoParser>)userInfoParser;

- (id)addAuthenticationCenterObserver:(id<ZMAuthenticationStatusObserver>)observer;

- (void)prepareForLoginWithCredentials:(ZMCredentials *)credentials;
- (void)continueAfterBackupImportStep;
- (void)prepareForRequestingPhoneVerificationCodeForLogin:(NSString *)phone;

- (void)didCompleteRequestForLoginCodeSuccessfully;
- (void)didFailRequestForLoginCode:(NSError *)error;

- (void)didCompletePhoneVerificationSuccessfully;

- (void)loginSucceededWithResponse:(ZMTransportResponse *)response;
- (void)loginSucceededWithUserInfo:(UserInfo *)userInfo;
- (void)didFailLoginWithPhone:(BOOL)invalidCredentials;
- (void)didFailLoginWithEmailBecausePendingValidation;
- (void)didFailLoginWithEmail:(BOOL)invalidCredentials;
- (void)didFailLoginBecauseAccountSuspended;
- (void)didTimeoutLoginForCredentials:(ZMCredentials *)credentials;

@end

@interface ZMAuthenticationStatus (CredentialProvider) <ZMCredentialProvider>

- (void)credentialsMayBeCleared;

@end


