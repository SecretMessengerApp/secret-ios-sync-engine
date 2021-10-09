// 


@import WireUtilities;

#import "NSURL+LaunchOptions.h"

@implementation NSURL (LaunchOptions)

- (NSString *)codeForPhoneVerification
{
    if (!self.isURLForPhoneVerification) {
        return nil;
    }
    return [self.path substringFromIndex:1];
}

- (BOOL)isURLForPhoneVerification
{
    return
    [self.scheme isEqualToString:@"wire"]
    && [self.host isEqualToString:@"verify-phone"]
    && self.path.length > 1;
}

@end
