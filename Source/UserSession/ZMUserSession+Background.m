// 


@import WireTransport;
@import WireDataModel;

#import "ZMUserSession+Internal.h"
#import "ZMOperationLoop+Private.h"
#import "ZMSyncStrategy.h"
#import "ZMMissingUpdateEventsTranscoder.h"
#import "ZMMissingHugeUpdateEventsTranscoder.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

static NSString *ZMLogTag = @"Push";

@implementation ZMUserSession (ZMBackground)

- (void)application:(id<ZMApplication>)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
{
    [self startEphemeralTimers];
    NSDictionary *payload = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (payload != nil) {
        [self application:application didReceiveRemoteNotification:payload fetchCompletionHandler:^(UIBackgroundFetchResult result) {
            NOT_USED(result);
        }];
    }
    [self.storedDidSaveNotifications clear];
}

- (void)application:(id<ZMApplication>)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
{
//    NotificationUserInfo *uinfo = [[NotificationUserInfo alloc] initWithStorage:userInfo];
//    [self handleNotificationResponseWithActionIdentifier: @"" categoryIdentifier:@"" userInfo:uinfo userText:@"" completionHandler:^{
//
//    }];
    NOT_USED(application);
    NOT_USED(userInfo);
    NOT_USED(completionHandler);
}

- (void)application:(id<ZMApplication>)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
{
    NOT_USED(application);
    [BackgroundActivityFactory.sharedFactory resume];
    [self.syncManagedObjectContext performGroupedBlock:^{
        [self.operationLoop.syncStrategy.missingUpdateEventsTranscoder startDownloadingMissingNotifications];
        [self.operationLoop.syncStrategy.missingHugeUpdateEventsTranscoder startDownloadingMissingNotifications];
        [self.operationStatus startBackgroundFetchWithCompletionHandler:completionHandler];
    }];
}

- (void)application:(id<ZMApplication>)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler;
{
    NOT_USED(application);
    NOT_USED(identifier);
    completionHandler();
}

- (void)applicationDidEnterBackground:(NSNotification *)note;
{
    NOT_USED(note);
    [self notifyThirdPartyServices];
    [self stopEphemeralTimers];
    [UserAliasname sync];
}

- (void)applicationWillEnterForeground:(NSNotification *)note;
{
    NOT_USED(note);
    self.didNotifyThirdPartyServices = NO;

    [self mergeChangesFromStoredSaveNotificationsIfNeeded];
    
    [self startEphemeralTimers];
    
    [UserAliasname getAliasName];
    
    // In the case that an ephemeral was sent via the share extension, we need
    // to ensure that they have timers running or are deleted/obfuscated if
    // needed. Note: ZMMessageTimer will only create a new timer for a message
    // if one does not already exist.
    [self.syncManagedObjectContext performGroupedBlock:^{
        [ZMMessage deleteOldEphemeralMessages:self.syncManagedObjectContext];
    }];
}

- (void)mergeChangesFromStoredSaveNotificationsIfNeeded
{
    NSArray *storedNotifications = self.storedDidSaveNotifications.storedNotifications.copy;
    [self.storedDidSaveNotifications clear];

    if (storedNotifications.count == 0) {
        return;
    }
    
    for (NSDictionary *changes in storedNotifications) {
        [NSManagedObjectContext mergeChangesFromRemoteContextSave:changes intoContexts:@[self.managedObjectContext]];
        [self.syncManagedObjectContext performGroupedBlock:^{
            [NSManagedObjectContext mergeChangesFromRemoteContextSave:changes intoContexts:@[self.syncManagedObjectContext]];
        }];
    }

    // we only process pending changes on sync context bc changes on the
    // ui context will be processed when we do the save.
    [self.syncManagedObjectContext performGroupedBlock:^{
        [self.syncManagedObjectContext processPendingChanges];
    }];
    
    [self.managedObjectContext saveOrRollback];
}

@end


@implementation ZMUserSession (ZMBackgroundFetch)

- (void)enableBackgroundFetch;
{
    // We enable background fetch by setting the minimum interval to something different from UIApplicationBackgroundFetchIntervalNever
    [self.application setMinimumBackgroundFetchInterval: UIApplicationBackgroundFetchIntervalMinimum];
}

@end
