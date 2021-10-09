// 

#import "ZMClientRegistrationStatus.h"

@class ZMEmailCredentials;

@protocol ZMCredentialProvider <NSObject>

- (void)credentialsMayBeCleared;
- (ZMEmailCredentials *)emailCredentials;
@end

@interface ZMClientRegistrationStatus ()
- (BOOL)isAddingEmailNecessary;
@end
