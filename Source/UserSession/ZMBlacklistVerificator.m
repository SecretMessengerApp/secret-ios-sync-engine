// 


@import WireSystem;
@import WireTransport;

#import "ZMBlacklistVerificator+Testing.h"
#import "ZMBlacklistDownloader.h"
#import "ZMUserSession.h"

@interface ZMBlacklistVerificator ()
@property (nonatomic) ZMBlacklistDownloader *downloader;
@end

@implementation ZMBlacklistVerificator

- (instancetype)initWithCheckInterval:(NSTimeInterval)checkInterval
                              version:(NSString *)version
                          environment:(id<BackendEnvironmentProvider>)environment
                         workingGroup:(ZMSDispatchGroup * _Nullable)workingGroup
                          application:(id<ZMApplication>)application
                    blacklistCallback:(void (^)(BOOL))blacklistCallback
{
    return [self initWithCheckInterval:checkInterval
                               version:version
                           environment:environment
                          workingGroup:workingGroup
                           application:application
                     blacklistCallback:blacklistCallback
                        blacklistClass:ZMBlacklistDownloader.class];
}

- (instancetype)initWithCheckInterval:(NSTimeInterval)checkInterval
                              version:(NSString *)version
                          environment:(id<BackendEnvironmentProvider>)environment
                         workingGroup:(ZMSDispatchGroup *)workingGroup
                          application:(id<ZMApplication>)application
                    blacklistCallback:(void (^)(BOOL))blacklistCallback
                       blacklistClass:(Class)blacklistClass
{
    self = [super init];
    if(self) {
        self.downloader = [[blacklistClass alloc] initWithDownloadInterval:checkInterval
                                                               environment:environment
                                                              workingGroup:workingGroup
                                                               application:application
                                                         completionHandler:^(NSString *minVersion, NSArray *excludedVersions) {
            [ZMBlacklistVerificator checkIfVersionIsBlacklisted:version completion:blacklistCallback minVersion:minVersion excludedVersions:excludedVersions];
        }];
    }
    return self;
}

+ (void)checkIfVersionIsBlacklisted:(NSString *)version completion:(void (^)(BOOL))completion minVersion:(NSString *)minVersion excludedVersions:(NSArray *)excludedVersions
{
    if (completion) {
        if ([version compare:minVersion
                     options:NSNumericSearch
                       range:NSMakeRange(0, version.length)
                      locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]] == NSOrderedAscending ||
            [excludedVersions containsObject:version]) {
            completion(YES);
        }
        else {
            completion(NO);
        }
    }
}

- (void)tearDown
{
    [self.downloader tearDown];
}

@end
