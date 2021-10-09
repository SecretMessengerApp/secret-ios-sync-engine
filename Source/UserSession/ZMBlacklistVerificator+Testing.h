// 


#import "ZMBlacklistVerificator.h"

@interface ZMBlacklistVerificator (Testing)

- (instancetype)initWithCheckInterval:(NSTimeInterval)checkInterval
                              version:(NSString *)version
                          environment:(id<BackendEnvironmentProvider>)environment
                         workingGroup:(ZMSDispatchGroup *)workingGroup
                          application:(id<ZMApplication>)application
                    blacklistCallback:(void (^)(BOOL))blacklistCallback
                       blacklistClass:(Class)blacklistClass;


@end
