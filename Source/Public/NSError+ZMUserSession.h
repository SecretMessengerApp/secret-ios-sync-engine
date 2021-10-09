// 


@import Foundation;


typedef NS_ENUM(NSUInteger, ZMAccountDeletedReason) {
    /// The user account was deleted by the user
    ZMAccountDeletedReasonUserInitiated = 0,
    /// The user account was deleted because a jailbreak was detected
    ZMAccountDeletedReasonJailbreakDetected,
    /// The user account was deleted because the session expired
    ZMAccountDeletedReasonSessionExpired
};

typedef NS_ENUM(NSUInteger, ZMUserSessionErrorCode) {
    ZMUserSessionNoError = 0,
    /// ???
    ZMUserSessionUnknownError,
    /// Credentials are needed to authenticate
    ZMUserSessionNeedsCredentials,
    /// The credentials provided are not valid
    ZMUserSessionInvalidCredentials,
    /// The account is still pending validation
    ZMUserSessionAccountIsPendingActivation,
    /// Network error in communicating with the backend
    ZMUserSessionNetworkError,
    /// The email used in the registration is already in use
    ZMUserSessionEmailIsAlreadyRegistered,
    /// The phone number used in the registration is already in use
    ZMUserSessionPhoneNumberIsAlreadyRegistered,
    /// The phone number used in the registration is not a valid phone number
    ZMUserSessionInvalidPhoneNumber,
    /// The email used in the registration is not a valid email
    ZMUserSessionInvalidEmail,
    /// The phone number verification code inserted is not valid
    ZMUserSessionInvalidPhoneNumberVerificationCode,
    /// The registration failed, but we don't know why
    ZMUserSessionRegistrationDidFailWithUnknownError,
    /// There is already a recent request to get the activation code for registration/login
    ZMUserSessionCodeRequestIsAlreadyPending,
    /// The user account does not have a password, and a password
    /// is needed to register a new client.
    ZMUserSessionNeedsPasswordToRegisterClient,
    /// The user account does not have an email, and an email
    /// is needed to register a new client
    /// Not supported by the backend any more. The error is generated locally.
    ZMUserSessionNeedsToRegisterEmailToRegisterClient,
    /// Too many clients have been registered for this user,
    /// one needs to be deleted before registering a new one
    ZMUserSessionCanNotRegisterMoreClients,
    /// The invitation code provided during registration is invalid
    ZMUserSessionInvalidInvitationCode,
    /// The Activation code provided during email activation is invalid
    ZMUserSessionInvalidActivationCode,
    /// The current usert client was deleted remotely
    ZMUserSessionClientDeletedRemotely,
    /// The last user identity (email or phone number) cannot be removed.
    ZMUserSessionLastUserIdentityCantBeDeleted,
    /// Access token expired and could not be renewed
    ZMUserSessionAccessTokenExpired,
    /// The user requested to add an additional account
    ZMUserSessionAddAccountRequested,
    /// The user account is suspended and may not be logged in
    ZMUserSessionAccountSuspended,
    /// The user account was deleted
    ZMUserSessionAccountDeleted,
    /// The account can't be created because the account limit has been reached
    ZMUserSessionAccountLimitReached,
    /// The email used in the registration is blacklisted
    ZMUserSessionBlacklistedEmail,
    /// Unauthorized e-mail address
    ZMUserSessionUnauthorizedEmail,
    /// User has rebooted the device
    ZMUserSessionNeedsAuthenticationAfterReboot
};

FOUNDATION_EXPORT NSString * const ZMClientsKey;

FOUNDATION_EXPORT NSString * const ZMUserLoginCredentialsKey;
FOUNDATION_EXPORT NSString * const ZMPhoneCredentialKey;
FOUNDATION_EXPORT NSString * const ZMEmailCredentialKey;
FOUNDATION_EXPORT NSString * const ZMUserHasPasswordKey;
FOUNDATION_EXPORT NSString * const ZMUserUsesCompanyLoginCredentialKey;
FOUNDATION_EXPORT NSString * const ZMAccountDeletedReasonKey;

@interface NSError (ZMUserSession)

/// Will return @c ZMUserSessionNoError if the receiver is not a user session error.
@property (nonatomic, readonly) ZMUserSessionErrorCode userSessionErrorCode;

@end
