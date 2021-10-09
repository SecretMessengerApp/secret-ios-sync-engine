// 


#import <WireSyncEngine/WireSyncEngine.h>

@interface ZMAuthenticationStatus () <ZMTimerClient>

@property (nonatomic, copy) NSString *registrationPhoneNumberThatNeedsAValidationCode;
@property (nonatomic, copy) NSString *loginPhoneNumberThatNeedsAValidationCode;

@property (nonatomic) ZMCredentials *internalLoginCredentials;
@property (nonatomic) ZMPhoneCredentials *registrationPhoneValidationCredentials;
@property (nonatomic) ZMCompleteRegistrationUser *internalRegistrationUser;

@property (nonatomic) BOOL isWaitingForEmailVerification;
@property (nonatomic) BOOL isWaitingForBackupImport;
@property (nonatomic) BOOL completedRegistration;

@property (nonatomic) BOOL isWaitingForLogin;
@property (nonatomic) BOOL canClearCredentials;

@property (nonatomic, weak) id<ZMSGroupQueue> groupQueue;
@property (nonatomic) ZMTimer *loginTimer;

- (void)resetLoginAndRegistrationStatus;
- (void)setLoginCredentials:(ZMCredentials *)credentials;

@end

