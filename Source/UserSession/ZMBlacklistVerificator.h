// 


#import <Foundation/Foundation.h>

@protocol ZMApplication;
@protocol BackendEnvironmentProvider;
@import WireUtilities;

@interface ZMBlacklistVerificator : NSObject <TearDownCapable>

NS_ASSUME_NONNULL_BEGIN

- (instancetype)initWithCheckInterval:(NSTimeInterval)checkInterval
                              version:(NSString *)version
                          environment:(id<BackendEnvironmentProvider>)environment
                         workingGroup:(ZMSDispatchGroup * _Nullable)workingGroup
                          application:(id<ZMApplication>)application
                    blacklistCallback:(void (^)(BOOL))blacklistCallback;

- (void)tearDown;

@end

NS_ASSUME_NONNULL_END
