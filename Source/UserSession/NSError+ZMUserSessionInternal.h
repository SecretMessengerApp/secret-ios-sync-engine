// 


#import "NSError+ZMUserSession.h"

NS_ASSUME_NONNULL_BEGIN

@class ZMTransportResponse;

@interface NSError (ZMUserSessionInternal)

+ (instancetype)userSessionErrorWithErrorCode:(ZMUserSessionErrorCode)code userInfo:(nullable NSDictionary *)userInfo;

+ (__nullable instancetype)pendingLoginErrorWithResponse:(ZMTransportResponse *)response;
+ (__nullable instancetype)unauthorizedErrorWithResponse:(ZMTransportResponse *)response;
+ (__nullable instancetype)unauthorizedEmailErrorWithResponse:(ZMTransportResponse *)response;

+ (__nullable instancetype)invalidPhoneNumberErrorWithReponse:(ZMTransportResponse *)response;
+ (__nullable instancetype)phoneNumberIsAlreadyRegisteredErrorWithResponse:(ZMTransportResponse *)response;

+ (__nullable instancetype)invalidPhoneVerificationCodeErrorWithResponse:(ZMTransportResponse *)response;

+ (__nullable instancetype)emailAddressInUseErrorWithResponse:(ZMTransportResponse *)response;
+ (__nullable instancetype)blacklistedEmailWithResponse:(ZMTransportResponse *)response;
+ (__nullable instancetype)invalidEmailWithResponse:(ZMTransportResponse *)response;
+ (__nullable instancetype)keyExistsErrorWithResponse:(ZMTransportResponse *)response;

+ (__nullable instancetype)invalidInvitationCodeWithResponse:(ZMTransportResponse *)response;

+ (__nullable instancetype)lastUserIdentityCantBeRemovedWithResponse:(ZMTransportResponse *)response;

+ (__nullable instancetype)invalidActivationCodeWithResponse:(ZMTransportResponse *)response;

@end

NS_ASSUME_NONNULL_END
