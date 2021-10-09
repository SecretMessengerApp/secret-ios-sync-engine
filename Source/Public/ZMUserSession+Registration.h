// 


@import WireSystem;

#import <WireSyncEngine/ZMUserSession.h>

@class ZMCompleteRegistrationUser;
@protocol ZMRegistrationObserverToken;
@protocol ZMRegistrationObserver;

@interface ZMUserSession (Registration)

/// Whether the user completed the registration on this device
@property (nonatomic, readonly) BOOL registeredOnThisDevice;

@end



@protocol ZMRegistrationObserver <NSObject>
@optional

/// Invoked when the registration failed
- (void)registrationDidFail:(NSError *)error;

/// Requesting the phone verification code failed (e.g. invalid number?) even before sending SMS
- (void)phoneVerificationCodeRequestDidFail:(NSError *)error;

/// Requesting the phone verification code succeded
- (void)phoneVerificationCodeRequestDidSucceed;

/// Invoked when any kind of phone verification was completed with the right code
- (void)phoneVerificationDidSucceed;

/// Invoked when any kind of phone verification failed because of wrong code/phone combination
- (void)phoneVerificationDidFail:(NSError *)error;

/// Email was correctly registered and validated
- (void)emailVerificationDidSucceed;

/// Email was already registered to another user
- (void)emailVerificationDidFail:(NSError *)error;

@end
