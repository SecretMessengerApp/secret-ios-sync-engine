// 


@import WireSystem;
@import WireUtilities;
@import WireDataModel;

#import "ZMTypingUsers.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

static NSString * const ZMTypingUsersKey = @"ZMTypingUsers";


@interface ZMTypingUsers ()

@property (nonatomic, readonly) NSMutableDictionary *conversationIDToUserIDs;

@end



@implementation ZMTypingUsers

- (instancetype)init
{
    self = [super init];
    if (self) {
        _conversationIDToUserIDs = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)updateTypingUsers:(NSSet<ZMUser *> *)typingUsers inConversation:(ZMConversation *)conversation
{
    NSManagedObjectID *conversationID = conversation.objectID;
    Require(! conversationID.isTemporaryID);
    NSSet *userIDs = [typingUsers mapWithBlock:^id(ZMUser *user) {
        NSManagedObjectID *moid = user.objectID;
        Require(! moid.isTemporaryID);
        return moid;
    }];
    if (userIDs.count == 0) {
        [self.conversationIDToUserIDs removeObjectForKey:conversationID];
    } else {
        self.conversationIDToUserIDs[conversationID] = userIDs;
    }
}

- (NSSet *)typingUsersInConversation:(ZMConversation *)conversation;
{
    VerifyReturnValue(conversation != nil, [NSSet set]);
    NSManagedObjectID *conversationID = conversation.objectID;
    NSManagedObjectContext *moc = conversation.managedObjectContext;
    VerifyReturnValue(! conversationID.isTemporaryID, [NSSet set]);
    NSSet *userIDs = self.conversationIDToUserIDs[conversationID];
    NSSet *users = [userIDs mapWithBlock:^id(NSManagedObjectID *moid) {
        return [moc objectWithID:moid];
    }];
    return users ?: [NSSet set];
}

@end



@implementation NSManagedObjectContext (ZMTypingUsers)

- (ZMTypingUsers *)typingUsers;
{
    if (! self.zm_isUserInterfaceContext) {
        return nil;
    }
    
    ZMTypingUsers *typingUsers = self.userInfo[ZMTypingUsersKey];
    if (typingUsers == nil) {
        typingUsers = [[ZMTypingUsers alloc] init];
        self.userInfo[ZMTypingUsersKey] = typingUsers;
    }
    return typingUsers;
}

@end



@implementation ZMConversation (ZMTypingUsers)

- (void)setIsTyping:(BOOL)isTyping;
{
    [TypingStrategy notifyTranscoderThatUserWithIsTyping:isTyping in:self];
}

- (NSSet *)typingUsers
{
    return [self.managedObjectContext.typingUsers typingUsersInConversation:self];
}

@end
