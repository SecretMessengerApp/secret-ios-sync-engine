// 


@import Foundation;


@interface ZMCredentials : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *email;
@property (nonatomic, copy, readonly, nullable) NSString *password;
@property (nonatomic, copy, nullable) NSString *token;
@property (nonatomic, copy, readonly, nullable) NSString *phoneNumber;
@property (nonatomic, copy, readonly, nullable) NSString *phoneNumberVerificationCode;

@property (nonatomic, readonly) BOOL credentialWithEmail;
@property (nonatomic, readonly) BOOL credentialWithPhone;

@end


@interface ZMPhoneCredentials : ZMCredentials

+ (nonnull ZMPhoneCredentials *)credentialsWithPhoneNumber:(nonnull NSString *)phoneNumber verificationCode:(nonnull NSString *)verificationCode;

@end


@interface ZMEmailCredentials : ZMCredentials



+ (nonnull ZMEmailCredentials *)credentialsWithEmail:(nonnull NSString *)email password:(nonnull NSString *)password;

@end
