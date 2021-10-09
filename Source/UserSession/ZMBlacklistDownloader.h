// 


@import Foundation;
@import WireUtilities;

@protocol ZMApplication;
@protocol BackendEnvironmentProvider;

@interface ZMBlacklistDownloader : NSObject <TearDownCapable>

/// Creates a downloader that will download the blacklist file at regular intervals and invokes the completion handler on the main queue when a blacklist is available
- (instancetype)initWithDownloadInterval:(NSTimeInterval)downloadInterval
                             environment:(id<BackendEnvironmentProvider>)environment
                            workingGroup:(ZMSDispatchGroup *)workingGroup
                             application:(id<ZMApplication>)application
                       completionHandler:(void (^)(NSString *minVersion, NSArray *excludedVersions))completionHandler;

@end
