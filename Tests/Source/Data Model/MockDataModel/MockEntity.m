// 

@import WireDataModel;
#import "MockEntity.h"

@implementation MockEntity

@dynamic field, field2, field3;
@dynamic testUUID;
@dynamic mockEntities;
@dynamic modifiedDataFields;

+(NSString *)sortKey {
    return @"field";
}

+(NSString *)entityName {
    return @"MockEntity";
}

+(NSString *)remoteIdentifierDataKey {
    return @"testUUID_data";
}

- (NSUUID *)testUUID;
{
    return [self transientUUIDForKey:@"testUUID"];
}

- (void)setTestUUID:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:@"testUUID"];
}

- (NSUUID *)remoteIdentifier;
{
    return [self transientUUIDForKey:@"remoteIdentifier"];
}

- (void)setRemoteIdentifier:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:@"remoteIdentifier"];
}

+ (NSArray *)sortDescriptorsForUpdating;
{
    return [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"field" ascending:YES]];
}

@end
