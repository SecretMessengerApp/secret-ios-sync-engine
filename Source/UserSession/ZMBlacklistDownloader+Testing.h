// 


#import "ZMBlacklistDownloader.h"

@protocol BackendEnvironmentProvider;

@interface ZMBlacklistDownloader (Testing)

- (instancetype)initWithURLSession:(NSURLSession *)session
                               env:(id<BackendEnvironmentProvider>)env
              successCheckInterval:(NSTimeInterval)successCheckInterval
              failureCheckInterval:(NSTimeInterval)failureCheckInterval
                      userDefaults:(NSUserDefaults *)userDefaults
                       application:application
                      workingGroup:(ZMSDispatchGroup *)workingGroup
                 completionHandler:(void (^)(NSString *minVersion, NSArray *excludedVersions))completionHandler;

@end
