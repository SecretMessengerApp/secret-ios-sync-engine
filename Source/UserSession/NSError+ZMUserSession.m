// 


@import WireTransport;

#import "NSError+ZMUserSession.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

NSString * const ZMClientsKey = @"clients";
NSString * const ZMPhoneCredentialKey = @"phone";
NSString * const ZMEmailCredentialKey = @"email";
NSString * const ZMUserHasPasswordKey = @"has-password";
NSString * const ZMUserUsesCompanyLoginCredentialKey = @"uses-company-login";
NSString * const ZMUserLoginCredentialsKey = @"login-credentials";
NSString * const ZMAccountDeletedReasonKey = @"account-deleted-reason";

@implementation NSError (ZMUserSession)

- (ZMUserSessionErrorCode)userSessionErrorCode
{
    if (! [self.domain isEqualToString:NSError.ZMUserSessionErrorDomain]) {
        return ZMUserSessionNoError;
    } else {
        return (ZMUserSessionErrorCode) self.code;
    }
}

@end



@implementation NSError (ZMUserSessionInteral)

+ (instancetype)userSessionErrorWithErrorCode:(ZMUserSessionErrorCode)code userInfo:(NSDictionary *)userInfo
{
    return [[NSError alloc] initWitUserSessionErrorWithErrorCode:code userInfo:userInfo];
}

+ (instancetype)pendingLoginErrorWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 403 && [[response payloadLabel] isEqualToString:@"pending-login"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionCodeRequestIsAlreadyPending userInfo:nil];
    }
    return nil;
}

+ (instancetype)unauthorizedErrorWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 403 && [[response payloadLabel] isEqualToString:@"unauthorized"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionInvalidPhoneNumber userInfo:nil];
    }
    return nil;
}

+ (instancetype)unauthorizedEmailErrorWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 403 && [[response payloadLabel] isEqualToString:@"unauthorized"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionUnauthorizedEmail userInfo:nil];
    }
    return nil;
}

+ (instancetype)invalidPhoneVerificationCodeErrorWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 404 && [[response payloadLabel] isEqualToString:@"invalid-code"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionInvalidPhoneNumberVerificationCode userInfo:nil];
    }
    return nil;
}

+ (instancetype)invalidPhoneNumberErrorWithReponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 400 && ([[response payloadLabel] isEqualToString:@"invalid-phone"] || [[response payloadLabel] isEqualToString:@"bad-request"])) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionInvalidPhoneNumber userInfo:nil];
    }
    return nil;
}

+ (instancetype)phoneNumberIsAlreadyRegisteredErrorWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 409) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionPhoneNumberIsAlreadyRegistered userInfo:nil];
    }
    return nil;
}

+ (instancetype)blacklistedEmailWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 403 && [[response payloadLabel] isEqualToString:@"blacklisted-email"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionBlacklistedEmail userInfo:nil];
    }
    return nil;
}

+ (instancetype)invalidEmailWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 400 && [[response payloadLabel] isEqualToString:@"invalid-email"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionInvalidEmail userInfo:nil];
    }
    return nil;
}

+ (__nullable instancetype)emailAddressInUseErrorWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 409 && [[response payloadLabel] isEqualToString:@"key-exists"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionEmailIsAlreadyRegistered userInfo:nil];
    }
    return nil;
}

+ (instancetype)keyExistsErrorWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 409 && [[response payloadLabel] isEqualToString:@"key-exists"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionEmailIsAlreadyRegistered userInfo:nil];
    }
    return nil;
}

+ (instancetype)invalidInvitationCodeWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 400 && [[response payloadLabel] isEqualToString:@"invalid-invitation-code"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionInvalidInvitationCode userInfo:nil];
    }
    return nil;
}

+ (instancetype)invalidActivationCodeWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 404 && [[response payloadLabel] isEqualToString:@"invalid-code"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionInvalidActivationCode userInfo:nil];
    }
    return nil;
}

+ (instancetype)lastUserIdentityCantBeRemovedWithResponse:(ZMTransportResponse *)response
{
    if (response.HTTPStatus == 403 && [[response payloadLabel] isEqualToString:@"last-identity"]) {
        return [NSError userSessionErrorWithErrorCode:ZMUserSessionLastUserIdentityCantBeDeleted userInfo:nil];
    }
    return nil;
}

@end
