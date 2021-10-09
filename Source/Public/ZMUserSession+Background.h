//


#import <WireSyncEngine/ZMUserSession.h>

@import UIKit;
@import UserNotifications;

@protocol ZMApplication;

@interface ZMUserSession (ZMBackground)

/// Process the payload of the remote notification. This may cause a @c UILocalNotification to be displayed.
- (void)application:(id<ZMApplication>)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;

/// Causes the user session to update its state from the backend.
- (void)application:(id<ZMApplication>)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;

/// Lets the user session process event for a background URL session it has set up.
- (void)application:(id<ZMApplication>)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler;

/// Lets the user session process local and remote notifications contained in the launch options;
- (void)application:(id<ZMApplication>)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;

- (void)applicationDidEnterBackground:(NSNotification *)note;
- (void)applicationWillEnterForeground:(NSNotification *)note;
- (void)mergeChangesFromStoredSaveNotificationsIfNeeded;

@end


// PRIVATE
@interface ZMUserSession (PushToken)

- (BOOL)isAuthenticated;

@end
