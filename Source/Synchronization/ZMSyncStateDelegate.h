// 

@class UserClient;



@protocol ZMClientRegistrationStatusDelegate <NSObject>

- (void)didRegisterUserClient:(UserClient *)userClient;

@end



@protocol ZMSyncStateDelegate <ZMClientRegistrationStatusDelegate>

/// The session did start the slow sync (fetching of users, conversations, ...)
- (void)didStartSlowSync;
/// The session did finish the slow sync
- (void)didFinishSlowSync;
/// The session did start the quick sync (fetching of the notification stream)
- (void)didStartQuickSync;
/// The session did finish the quick sync
- (void)didFinishQuickSync;

@end

