// 


@import WireDataModel;

#import <CoreData/CoreData.h>
#import <WireUtilities/WireUtilities.h>

#import "MockModelObjectContextFactory.h"
#import "MockEntity.h"
#import "MockEntity2.h"



@implementation MockModelObjectContextFactory

+ (NSManagedObjectContext *)alternativeMocForPSC:(NSPersistentStoreCoordinator *)psc
{
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc createDispatchGroups];
    [moc setPersistentStoreCoordinator:psc];
    [moc markAsSyncContext];
    [moc disableObjectRefresh];
    return moc;
}

+ (NSManagedObjectContext *)testContext;
{
    NSManagedObjectModel *mom = [self loadManagedObjectModel];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    
    NSError *error = nil;
    __unused NSPersistentStore *store = [psc addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error];
    NSAssert(store != nil, @"Unable to create in-memory Core Data store: %@", error);
    
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc createDispatchGroups];
    [moc setPersistentStoreCoordinator:psc];
    [moc markAsUIContext];
    [moc disableObjectRefresh];

    return moc;

}

+ (NSManagedObjectModel *)loadManagedObjectModel;
{
    NSEntityDescription *mockEntity = [self createMockEntityDescription];
    NSEntityDescription *mockEntity2 = [self createMockEntity2];

    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];
    [model setEntities:@[mockEntity, mockEntity2]];

    return model;
}

+ (NSEntityDescription *)createMockEntity2
{
    NSAttributeDescription *fieldAttribute = [[NSAttributeDescription alloc] init];
    [fieldAttribute setName:@"field"];
    [fieldAttribute setAttributeType:NSInteger16AttributeType];
    [fieldAttribute setOptional:YES];
    
    NSAttributeDescription *testUUIDAttribute = [[NSAttributeDescription alloc] init];
    [testUUIDAttribute setName:@"testUUID"];
    [testUUIDAttribute setAttributeType:NSUndefinedAttributeType];
    [testUUIDAttribute setOptional:YES];
    [testUUIDAttribute setTransient:YES];
    
    NSAttributeDescription *testUUIDDataAttribute = [[NSAttributeDescription alloc] init];
    [testUUIDDataAttribute setName:@"testUUID_data"];
    [testUUIDDataAttribute setAttributeType:NSBinaryDataAttributeType];
    [testUUIDDataAttribute setOptional:YES];
    [testUUIDDataAttribute setIndexed:YES];
    
    
    NSAttributeDescription *needsToBeUpdatedFromBackendAttribute = [[NSAttributeDescription alloc] init];
    [needsToBeUpdatedFromBackendAttribute setName:@"needsToBeUpdatedFromBackend"];
    [needsToBeUpdatedFromBackendAttribute setAttributeType:NSBooleanAttributeType];
    [needsToBeUpdatedFromBackendAttribute setOptional:YES];

    NSAttributeDescription *modifiedDataFieldsAttribute = [[NSAttributeDescription alloc] init];
    [modifiedDataFieldsAttribute setName:@"modifiedDataFields"];
    [modifiedDataFieldsAttribute setAttributeType:NSInteger64AttributeType];
    [modifiedDataFieldsAttribute setOptional:YES];


    NSEntityDescription *mockEntity2 = [[NSEntityDescription alloc] init];
    [mockEntity2 setName:@"MockEntity2"];
    [mockEntity2 setManagedObjectClassName:NSStringFromClass([MockEntity2 class])];

    [mockEntity2 setProperties:@[fieldAttribute, modifiedDataFieldsAttribute, needsToBeUpdatedFromBackendAttribute, testUUIDAttribute, testUUIDDataAttribute]];
    return mockEntity2;
}

+ (NSEntityDescription *)createMockEntityDescription
{
    NSEntityDescription *mockEntity = [[NSEntityDescription alloc] init];
    [mockEntity setName:@"MockEntity"];
    [mockEntity setManagedObjectClassName:NSStringFromClass([MockEntity class])];

    NSAttributeDescription *fieldAttribute = [[NSAttributeDescription alloc] init];
    [fieldAttribute setName:@"field"];
    [fieldAttribute setAttributeType:NSInteger16AttributeType];
    [fieldAttribute setOptional:YES];

    NSAttributeDescription *field2Attribute = [[NSAttributeDescription alloc] init];
    [field2Attribute setName:@"field2"];
    [field2Attribute setAttributeType:NSStringAttributeType];
    [field2Attribute setOptional:YES];

    NSAttributeDescription *field3Attribute = [[NSAttributeDescription alloc] init];
    [field3Attribute setName:@"field3"];
    [field3Attribute setAttributeType:NSStringAttributeType];
    [field3Attribute setOptional:YES];

    NSRelationshipDescription *mockEntityRelationship = [[NSRelationshipDescription alloc] init];
    [mockEntityRelationship setName:@"mockEntities"];
    [mockEntityRelationship setDestinationEntity:mockEntity];
    [mockEntityRelationship setMinCount:0];
    [mockEntityRelationship setOptional:YES];

    NSAttributeDescription *remoteIdentifierAttribute = [[NSAttributeDescription alloc] init];
    [remoteIdentifierAttribute setName:@"remoteIdentifier"];
    [remoteIdentifierAttribute setAttributeType:NSUndefinedAttributeType];
    [remoteIdentifierAttribute setOptional:YES];
    [remoteIdentifierAttribute setTransient:YES];
    
    NSAttributeDescription *remoteIdentifierDataAttribute = [[NSAttributeDescription alloc] init];
    [remoteIdentifierDataAttribute setName:@"remoteIdentifier_data"];
    [remoteIdentifierDataAttribute setAttributeType:NSBinaryDataAttributeType];
    [remoteIdentifierDataAttribute setOptional:YES];
    [remoteIdentifierDataAttribute setIndexed:YES];
    
    NSAttributeDescription *testUUIDAttribute = [[NSAttributeDescription alloc] init];
    [testUUIDAttribute setName:@"testUUID"];
    [testUUIDAttribute setAttributeType:NSUndefinedAttributeType];
    [testUUIDAttribute setOptional:YES];
    [testUUIDAttribute setTransient:YES];

    NSAttributeDescription *testUUIDDataAttribute = [[NSAttributeDescription alloc] init];
    [testUUIDDataAttribute setName:@"testUUID_data"];
    [testUUIDDataAttribute setAttributeType:NSBinaryDataAttributeType];
    [testUUIDDataAttribute setOptional:YES];
    [testUUIDDataAttribute setIndexed:YES];

    NSAttributeDescription *needsToBeUpdatedFromBackendAttribute = [[NSAttributeDescription alloc] init];
    [needsToBeUpdatedFromBackendAttribute setName:@"needsToBeUpdatedFromBackend"];
    [needsToBeUpdatedFromBackendAttribute setAttributeType:NSBooleanAttributeType];
    [needsToBeUpdatedFromBackendAttribute setOptional:YES];


    NSAttributeDescription *modifiedDataFieldsAttribute = [[NSAttributeDescription alloc] init];
    [modifiedDataFieldsAttribute setName:@"modifiedDataFields"];
    [modifiedDataFieldsAttribute setAttributeType:NSInteger64AttributeType];
    [modifiedDataFieldsAttribute setOptional:YES];

    [mockEntity setProperties:@[fieldAttribute, field2Attribute, field3Attribute, testUUIDAttribute,
        testUUIDDataAttribute, needsToBeUpdatedFromBackendAttribute, modifiedDataFieldsAttribute, mockEntityRelationship, remoteIdentifierAttribute, remoteIdentifierDataAttribute]];
    return mockEntity;
}

@end
