//


#import "ZMSyncStrategy+Internal.h"
#import "ZMSyncStrategy+ManagedObjectChanges.h"
#import "WireSyncEngineLogs.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

@implementation ZMSyncStrategy (ManagedObjectChanges)

- (void)logDidSaveNotification:(NSNotification *)note;
{
//    NSManagedObjectContext * ZM_UNUSED moc = note.object;
//    ZMLogWithLevelAndTag(ZMLogLevelDebug, ZMTAG_CORE_DATA, @"<%@: %p> did save. Context type = %@",
//                         moc.class, moc,
//                         moc.zm_isUserInterfaceContext ? @"UI" : moc.zm_isSyncContext ? @"Sync" : @"");
//    NSSet *inserted = note.userInfo[NSInsertedObjectsKey];
//    if (inserted.count > 0) {
//        NSString * ZM_UNUSED description = [[inserted.allObjects mapWithBlock:^id(NSManagedObject *mo) {
//            return mo.objectID.URIRepresentation;
//        }] componentsJoinedByString:@", "];
//        ZMLogWithLevelAndTag(ZMLogLevelDebug, ZMTAG_CORE_DATA, @"    Inserted: %@", description);
//        [self.eventProcessingTracker registerDataInsertionPerformedWithAmount:inserted.count];
//    }
//    NSSet *updated = note.userInfo[NSUpdatedObjectsKey];
//    if (updated.count > 0) {
//        NSString * ZM_UNUSED description = [[updated.allObjects mapWithBlock:^id(NSManagedObject *mo) {
//            return mo.objectID.URIRepresentation;
//        }] componentsJoinedByString:@", "];
//        ZMLogWithLevelAndTag(ZMLogLevelDebug, ZMTAG_CORE_DATA, @"    Updated: %@", description);
//        [self.eventProcessingTracker registerDataUpdatePerformedWithAmount:updated.count];
//    }
//    NSSet *deleted = note.userInfo[NSDeletedObjectsKey];
//    if (deleted.count > 0) {
//        NSString * ZM_UNUSED description = [[deleted.allObjects mapWithBlock:^id(NSManagedObject *mo) {
//            return mo.objectID.URIRepresentation;
//        }] componentsJoinedByString:@", "];
//        ZMLogWithLevelAndTag(ZMLogLevelDebug, ZMTAG_CORE_DATA, @"    Deleted: %@", description);
//        [self.eventProcessingTracker registerDataDeletionPerformedWithAmount:deleted.count];
//    }
}

- (void)managedObjectContextDidSave:(NSNotification *)note;
{
    if(self.tornDown || self.contextMergingDisabled) {
        return;
    }
    
    if([ZMSLog getLevelWithTag:ZMTAG_CORE_DATA] == ZMLogLevelDebug
       || [ZMSLog getLevelWithTag:ZMTAG_EVENT_PROCESSING] == ZMLogLevelDebug) {
        [self logDidSaveNotification:note];
    }
    
    NSManagedObjectContext *mocThatSaved = note.object;
    NSManagedObjectContext *strongUiMoc = self.uiMOC;
    NSDictionary *userInfo = [mocThatSaved.userInfo copy];
    
    if (mocThatSaved.zm_isUserInterfaceContext && strongUiMoc != nil) {
        if(mocThatSaved != strongUiMoc) {
            RequireString(mocThatSaved == strongUiMoc, "Not the right MOC!");
        }
        
        ZM_WEAK(self);
        [self.syncMOC performGroupedBlock:^{
            ZM_STRONG(self);
            if(self == nil || self.tornDown) {
                return;
            }
            [self.syncMOC mergeUserInfoFromUserInfo:userInfo];
            [self.syncMOC mergeChangesFromContextDidSaveNotification:note];
            [self.syncMOC processPendingChanges]; // We need this because merging sometimes leaves the MOC in a 'dirty' state
            [self.eventProcessingTracker registerSavePerformed];
        }];
        
        [self.msgMOC performGroupedBlock:^{
            ZM_STRONG(self);
            if(self == nil || self.tornDown) {
                return;
            }
            [self.msgMOC mergeUserInfoFromUserInfo:userInfo];
            [self.msgMOC mergeChangesFromContextDidSaveNotification:note];
            [self.msgMOC processPendingChanges]; // We need this because merging sometimes leaves the MOC in a 'dirty' state
        }];
        
    } else if (mocThatSaved.zm_isSyncContext) {
        
        //        RequireString(mocThatSaved != self.syncMOC, "Not the right MOC!");
        
        NSSet<NSManagedObjectID*>* changedObjectsIDs = [self extractManagedObjectIDsFrom:note];
        
        ZM_WEAK(self);
        [strongUiMoc performGroupedBlock:^{
            ZM_STRONG(self);
            if(self == nil || self.tornDown) {
                return;
            }
            
            [strongUiMoc mergeUserInfoFromUserInfo:userInfo];
            [strongUiMoc mergeChangesFromContextDidSaveNotification:note];
            [strongUiMoc processPendingChanges]; // We need this because merging sometimes leaves the MOC in a 'dirty' state
            [self.notificationDispatcher didMergeChanges:changedObjectsIDs];
            [self.eventProcessingTracker registerSavePerformed];
        }];
        
        [self.msgMOC performGroupedBlock:^{
            ZM_STRONG(self);
            if(self == nil || self.tornDown) {
                return;
            }
            [self.msgMOC mergeUserInfoFromUserInfo:userInfo];
            [self.msgMOC mergeChangesFromContextDidSaveNotification:note];
            [self.msgMOC processPendingChanges]; // We need this because merging sometimes leaves the MOC in a 'dirty' state
        }];
        
    } else if (mocThatSaved.zm_isMsgContext) {
        
        //        RequireString(mocThatSaved != self.syncMOC, "Not the right MOC!");
        
        NSSet<NSManagedObjectID*>* changedObjectsIDs = [self extractManagedObjectIDsFrom:note];
        
        ZM_WEAK(self);
        [strongUiMoc performGroupedBlock:^{
            ZM_STRONG(self);
            if(self == nil || self.tornDown) {
                return;
            }
            
            [strongUiMoc mergeUserInfoFromUserInfo:userInfo];
            [strongUiMoc mergeChangesFromContextDidSaveNotification:note];
            [strongUiMoc processPendingChanges]; // We need this because merging sometimes leaves the MOC in a 'dirty' state
            [self.notificationDispatcher didMergeChanges:changedObjectsIDs];
            [self.eventProcessingTracker registerSavePerformed];
        }];
        
        [self.syncMOC performGroupedBlock:^{
            ZM_STRONG(self);
            if(self == nil || self.tornDown) {
                return;
            }
            [self.syncMOC mergeUserInfoFromUserInfo:userInfo];
            [self.syncMOC mergeChangesFromContextDidSaveNotification:note];
            [self.syncMOC processPendingChanges]; // We need this because merging sometimes leaves the MOC in a 'dirty' state
            [self.eventProcessingTracker registerSavePerformed];
        }];
    }
}

- (NSSet<NSManagedObjectID*>*)extractManagedObjectIDsFrom:(NSNotification *)note
{
    NSSet<NSManagedObjectID*>* changedObjectsIDs;
    if (note.userInfo[NSUpdatedObjectsKey] != nil) {
        NSSet<NSManagedObject *>* changedObjects = note.userInfo[NSUpdatedObjectsKey];
        changedObjectsIDs = [changedObjects mapWithBlock:^id(NSManagedObject* obj) {
            return obj.objectID;
        }];
    } else {
        changedObjectsIDs = [NSSet set];
    }
    return changedObjectsIDs;
}

- (BOOL)processSaveWithInsertedObjects:(NSSet *)insertedObjects updateObjects:(NSSet *)updatedObjects
{
    NSSet *allObjects = [NSSet zmSetByCompiningSets:insertedObjects, updatedObjects, nil];
    
    for(id<ZMContextChangeTracker> tracker in self.allChangeTrackers)
    {
        [tracker objectsDidChange:allObjects];
    }
    
    return YES;
}

- (BOOL)processSaveWithMessageInsertedObjects:(NSSet *)insertedObjects updateObjects:(NSSet *)updatedObjects
{
    NSSet *allObjects = [NSSet zmSetByCompiningSets:insertedObjects, updatedObjects, nil];
    
    for(id<ZMContextChangeTracker> tracker in self.messageTrackers)
    {
        [tracker objectsDidChange:allObjects];
    }
    
    return YES;
}


@end
