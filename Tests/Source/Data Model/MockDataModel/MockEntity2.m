// 



#import "MockEntity2.h"

#import <WireDataModel/ZMManagedObject+Internal.h>

@implementation MockEntity2

@dynamic field;

+ (NSString *)entityName
{
    return @"MockEntity2";
}

+ (NSString *)sortKey
{
    return @"field";
}

+ (NSString *)remoteIdentifierDataKey
{
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

@end
