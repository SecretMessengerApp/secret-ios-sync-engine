//


#import "ZMSyncStrategy.h"

@interface ZMSyncStrategy (ManagedObjectChanges)

- (void)managedObjectContextDidSave:(NSNotification *)note;
- (BOOL)processSaveWithInsertedObjects:(NSSet *)insertedObjects updateObjects:(NSSet *)updatedObjects;
- (BOOL)processSaveWithMessageInsertedObjects:(NSSet *)insertedObjects updateObjects:(NSSet *)updatedObjects;

@end
