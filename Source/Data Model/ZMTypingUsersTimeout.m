// 


@import WireUtilities;
@import WireSystem;
@import WireDataModel;

#import "ZMTypingUsersTimeout.h"


@interface ZMUserAndConversationKey : NSObject <NSCopying>

+ (instancetype)keyWithUser:(ZMUser *)user conversation:(ZMConversation *)conversation;

@property (nonatomic, readonly) NSManagedObjectID *userObjectID;
@property (nonatomic, readonly) NSManagedObjectID *conversationObjectID;

@end



@interface ZMTypingUsersTimeout ()

@property (nonatomic, readonly) NSMutableDictionary *timeouts;

@end



@implementation ZMTypingUsersTimeout

- (instancetype)init
{
    self = [super init];
    if (self) {
        _timeouts = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addUser:(ZMUser *)user conversation:(ZMConversation *)conversation withTimeout:(NSDate *)timeout;
{
    Require(user != nil);
    Require(conversation != nil);
    Require(timeout != nil);
    ZMUserAndConversationKey *key = [ZMUserAndConversationKey keyWithUser:user conversation:conversation];
    self.timeouts[key] = timeout;
}

- (void)removeUser:(ZMUser *)user conversation:(ZMConversation *)conversation;
{
    Require(user != nil);
    Require(conversation != nil);
    ZMUserAndConversationKey *key = [ZMUserAndConversationKey keyWithUser:user conversation:conversation];
    [self.timeouts removeObjectForKey:key];
}


- (BOOL)containsUser:(ZMUser *)user conversation:(ZMConversation *)conversation;
{
    Require(user != nil);
    Require(conversation != nil);
    ZMUserAndConversationKey *key = [ZMUserAndConversationKey keyWithUser:user conversation:conversation];
    return self.timeouts[key] != nil;
}

- (NSDate *)firstTimeout;
{
    NSDate *minDate;
    for (NSDate *date in self.timeouts.allValues) {
        if (minDate == nil ||
            [minDate compare:date] == NSOrderedDescending){
            minDate = date;
        }
    }
    return minDate;
}

- (NSSet *)userIDsInConversation:(ZMConversation *)conversation
{
    NSArray *userIDs = [self.timeouts.allKeys mapWithBlock:^id(ZMUserAndConversationKey *key) {
        return ([key.conversationObjectID isEqual:conversation.objectID] ? key.userObjectID : nil);
    }];
    return [NSSet setWithArray:userIDs];
}

- (NSSet *)pruneConversationsThatHaveTimedOutAfter:(NSDate *)pruneDate;
{
    NSMutableSet *conversations = [NSMutableSet set];
    NSMutableArray *keysToRemove = [NSMutableArray array];
    [self.timeouts enumerateKeysAndObjectsUsingBlock:^(ZMUserAndConversationKey *key, NSDate *timeout, BOOL * __unused stop) {
        if ([timeout compare:pruneDate] == NSOrderedAscending){
            [conversations addObject:key.conversationObjectID];
            [keysToRemove addObject:key];
        }
    }];
    for (id key in keysToRemove) {
        [self.timeouts removeObjectForKey:key];
    }
    return conversations;
}

@end



@implementation ZMUserAndConversationKey

+ (instancetype)keyWithUser:(ZMUser *)user conversation:(ZMConversation *)conversation;
{
    Require(user != nil);
    Require(conversation != nil);
    ZMUserAndConversationKey *key = [[self alloc] init];
    if (key != nil) {
        // We need the object IDs to be permanent. We shouldn't see temporary ones, but since we can recover, do so.
        BOOL const identifierIsTemporary = (user.objectID.isTemporaryID ||
                                            conversation.objectID.isTemporaryID);
        if (identifierIsTemporary)
        {
            NSError *error;
            NSArray *objects = @[user, conversation];
            RequireString([user.managedObjectContext obtainPermanentIDsForObjects:objects error:&error],
                          "Failed to obtain permanent object IDs: %ld", (long) error.code);
        }
        key->_userObjectID = user.objectID;
        key->_conversationObjectID = conversation.objectID;
        Require(! key.userObjectID.isTemporaryID);
        Require(! key.conversationObjectID.isTemporaryID);
    }
    return key;
}

- (NSUInteger)hash;
{
    return self.userObjectID.hash ^ self.conversationObjectID.hash;
}

- (BOOL)isEqual:(id)object;
{
    if (! [object isKindOfClass:ZMUserAndConversationKey.class]) {
        return NO;
    }
    ZMUserAndConversationKey *other = object;
    return ([other.userObjectID isEqual:self.userObjectID] &&
            [other.conversationObjectID isEqual:self.conversationObjectID]);
}

- (id)copyWithZone:(NSZone * __unused)zone;
{
    return self;
}

@end
