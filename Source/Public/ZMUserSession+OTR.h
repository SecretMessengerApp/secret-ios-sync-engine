// 


#import <WireSyncEngine/WireSyncEngine.h>

@class UserClient;

NS_ASSUME_NONNULL_BEGIN

@protocol ZMClientUpdateObserver <NSObject>

- (void)finishedFetchingClients:(NSArray<UserClient *>*)userClients;
- (void)failedToFetchClientsWithError:(NSError *)error;
- (void)finishedDeletingClients:(NSArray<UserClient *>*)remainingClients;
- (void)failedToDeleteClientsWithError:(NSError *)error;

@end


@interface ZMUserSession (OTR)

/// Fetch all selfUser clients to manage them from the settings screen
/// The current client must be already registered
/// Calling this method without a registered client will throw an error
- (void)fetchAllClients;

/// Deletes selfUser clients from the BE when managing them from the settings screen
- (void)deleteClient:(UserClient *)client withCredentials:(nullable ZMEmailCredentials *)emailCredentials;

/// Adds an observer that is notified when the selfUser clients were successfully fetched and deleted
/// Returns a token that needs to be stored as long the observer should be active.
- (id)addClientUpdateObserver:(id<ZMClientUpdateObserver>)observer;

@end

NS_ASSUME_NONNULL_END
