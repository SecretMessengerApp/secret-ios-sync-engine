// 


@import WireSystem;
@import WireUtilities;
@import WireRequestStrategy;

#import "ZMUserSession+OTR.h"
#import "ZMUserSession+Internal.h"
#import "ZMCredentials.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>
#import "ZMUserSession+OTR.h"


@implementation ZMUserSession (OTR)

- (void)fetchAllClients
{
    [self.syncManagedObjectContext performGroupedBlock:^{
        [self.clientUpdateStatus needsToFetchClientsWithAndVerifySelfClient:YES];
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
    }];
}


- (void)deleteClient:(UserClient *)client withCredentials:(ZMEmailCredentials *)emailCredentials
{
    [client markForDeletion];
    [[client managedObjectContext] saveOrRollback];
    
    [self.syncManagedObjectContext performGroupedBlock:^{
        [self.clientUpdateStatus deleteClientsWithCredentials:emailCredentials];
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
    }];
}

- (id)addClientUpdateObserver:(id<ZMClientUpdateObserver>)observer;
{
    ZM_WEAK(observer);
    
    return [ZMClientUpdateNotification addOserverWithContext:self.managedObjectContext block:^(enum ZMClientUpdateNotificationType type, NSArray<NSManagedObjectID *> *clientObjectIDs, NSError *error) {
        ZM_STRONG(observer);
        [self.managedObjectContext performGroupedBlock:^{
            switch (type) {
                case ZMClientUpdateNotificationTypeFetchCompleted:
                    if ([observer respondsToSelector:@selector(finishedFetchingClients:)]) {
                        NSArray *uiClients = @[];
                        if (clientObjectIDs.count > 0) {
                            uiClients = [clientObjectIDs mapWithBlock:^id(NSManagedObjectID *objID) {
                                return [self.managedObjectContext objectWithID:objID];
                            }];
                        }
                        [observer finishedFetchingClients:uiClients];
                    }
                    break;
                case ZMClientUpdateNotificationTypeFetchFailed:
                    if ([observer respondsToSelector:@selector(failedToFetchClientsWithError:)]) {
                        [observer failedToFetchClientsWithError:error];
                    }
                    break;
                case ZMClientUpdateNotificationTypeDeletionCompleted:
                    if ([observer respondsToSelector:@selector(finishedDeletingClients:)]) {
                        NSArray *uiClients = @[];
                        if (clientObjectIDs.count > 0) {
                            uiClients = [clientObjectIDs mapWithBlock:^id(NSManagedObjectID *objID) {
                                return [self.managedObjectContext objectWithID:objID];
                            }];
                        }
                        [observer finishedDeletingClients:uiClients];
                    }
                    break;
                case ZMClientUpdateNotificationTypeDeletionFailed:
                    if ([observer respondsToSelector:@selector(failedToDeleteClientsWithError:)]) {
                        [observer failedToDeleteClientsWithError:error];
                    }
                    break;
            }
        }];

    }];
}



@end
