// 


@import Foundation;
@import WireSystem;

@class ZMAuthenticationStatus;
@class UnauthenticatedSession;


typedef NS_ENUM(NSUInteger, ZMUserSessionRegistrationNotificationType) {
    ZMRegistrationNotificationEmailVerificationDidSucceed,
    ZMRegistrationNotificationEmailVerificationDidFail,
    ZMRegistrationNotificationPhoneNumberVerificationDidSucceed,
    ZMRegistrationNotificationPhoneNumberVerificationDidFail,
    ZMRegistrationNotificationPhoneNumberVerificationCodeRequestDidFail,
    ZMRegistrationNotificationPhoneNumberVerificationCodeRequestDidSucceed,
    ZMRegistrationNotificationRegistrationDidFail
};

@interface ZMUserSessionRegistrationNotification : NSObject

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic) NSError *error;
@property (nonatomic) ZMUserSessionRegistrationNotificationType type;

/// Notifies all @c ZMAuthenticationObserver that the authentication failed
+ (void)notifyRegistrationDidFail:(NSError *)error context:(ZMAuthenticationStatus *)authenticationStatus;
+ (void)notifyPhoneNumberVerificationDidFail:(NSError *)error context:(ZMAuthenticationStatus *)authenticationStatus;
+ (void)notifyPhoneNumberVerificationCodeRequestDidFail:(NSError *)error context:(ZMAuthenticationStatus *)authenticationStatus;

+ (void)notifyEmailVerificationDidSucceedInContext:(ZMAuthenticationStatus *)authenticationStatus;
+ (void)notifyPhoneNumberVerificationDidSucceedInContext:(ZMAuthenticationStatus *)authenticationStatus;
+ (void)notifyPhoneNumberVerificationCodeRequestDidSucceedInContext:(ZMAuthenticationStatus *)authenticationStatus;

+ (id)addObserverInSession:(UnauthenticatedSession *)session withBlock:(void(^)(ZMUserSessionRegistrationNotificationType event, NSError *error))block ZM_MUST_USE_RETURN;
+ (id)addObserverInContext:(ZMAuthenticationStatus *)context withBlock:(void(^)(ZMUserSessionRegistrationNotificationType event, NSError *error))block ZM_MUST_USE_RETURN;

+ (NSNotificationName)name;

@end


@protocol ZMRequestVerificationEmailObserver
- (void)didReceiveRequestToResendValidationEmail;
@end


@interface ZMUserSessionRegistrationNotification (VerificationEmail)

+ (void)resendValidationForRegistrationEmailInContext:(ZMAuthenticationStatus *)context;
+ (id)addObserverForRequestForVerificationEmail:(id<ZMRequestVerificationEmailObserver>)observer context:(ZMAuthenticationStatus *)context ZM_MUST_USE_RETURN;

@end

