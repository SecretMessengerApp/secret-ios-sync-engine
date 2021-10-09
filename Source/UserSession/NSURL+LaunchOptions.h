// 


#import <Foundation/Foundation.h>

@interface NSURL (LaunchOptions)

- (BOOL)isURLForPhoneVerification;

- (NSString *)codeForPhoneVerification;

@end
