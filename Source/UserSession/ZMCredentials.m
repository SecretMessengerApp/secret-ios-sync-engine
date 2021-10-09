// 


@import WireUtilities;

#import "ZMCredentials+Internal.h"

@interface ZMCredentials ()

@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *password;
@property (nonatomic, copy, nullable) NSString *phoneNumber;
@property (nonatomic, copy, nullable) NSString *phoneNumberVerificationCode;

@end



@implementation ZMPhoneCredentials

+ (nonnull ZMPhoneCredentials *)credentialsWithPhoneNumber:(nonnull NSString *)phoneNumber verificationCode:(nonnull NSString *)verificationCode
{
    ZMPhoneCredentials *credentials = [[ZMPhoneCredentials alloc] init];
    credentials.phoneNumber = [ZMPhoneNumberValidator validatePhoneNumber: phoneNumber];
    credentials.phoneNumberVerificationCode = verificationCode;
    return credentials;
}

@end



@implementation ZMEmailCredentials

+ (nonnull ZMEmailCredentials *)credentialsWithEmail:(nonnull NSString *)email password:(nonnull NSString *)password
{
    ZMEmailCredentials *credentials = [[ZMEmailCredentials alloc] init];
    credentials.email = email;
    credentials.password = password;
    return credentials;
}

@end



@implementation ZMCredentials

#define ZM_EQUAL_STRINGS(a, b) (a == nil && b == nil) || [a isEqualToString:b]

- (BOOL)isEqual:(ZMCredentials *)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    BOOL emailsEqual = ZM_EQUAL_STRINGS(self.email, object.email);
    BOOL passwordsEqual = ZM_EQUAL_STRINGS(self.password, object.password);
    BOOL phoneNumbersEqual = ZM_EQUAL_STRINGS(self.phoneNumber, object.phoneNumber);
    BOOL phoneNumberCodesEqual = ZM_EQUAL_STRINGS(self.phoneNumberVerificationCode, object.phoneNumberVerificationCode);
    return emailsEqual && passwordsEqual && phoneNumbersEqual && phoneNumberCodesEqual;
}

#undef ZM_EQUAL_STRINGS

- (BOOL)credentialWithEmail {
    return self.email != nil;
}

- (BOOL)credentialWithPhone {
    return self.phoneNumber != nil;
}

@end
