// 


#import "ZMLoginTranscoder.h"
#import "ZMAuthenticationStatus.h"

extern NSString * const ZMLoginURL;
extern NSString * const ZMResendVerificationURL;
extern NSTimeInterval DefaultPendingValidationLoginAttemptInterval;

@class ZMTimedSingleRequestSync;
@class ZMAuthenticationStatus;

@interface ZMLoginTranscoder () <ZMSingleRequestTranscoder, ZMAuthenticationStatusObserver>

- (instancetype)initWithGroupQueue:(id<ZMSGroupQueue>)groupQueue
              authenticationStatus:(ZMAuthenticationStatus *)authenticationStatus
               timedDownstreamSync:(ZMTimedSingleRequestSync *)timedDownstreamSync
         verificationResendRequest:(ZMSingleRequestSync *)verificationResendRequest NS_DESIGNATED_INITIALIZER;

@property (nonatomic) ZMTimedSingleRequestSync *timedDownstreamSync;
@property (nonatomic) ZMSingleRequestSync *loginWithPhoneNumberSync;

@end
