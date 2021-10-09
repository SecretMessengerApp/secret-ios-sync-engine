// 


@import Foundation;
@class ZMUser;
@class ZMConversation;



@interface ZMTypingUsersTimeout : NSObject

- (void)addUser:(ZMUser *)user conversation:(ZMConversation *)conversation withTimeout:(NSDate *)timeout;
- (void)removeUser:(ZMUser *)user conversation:(ZMConversation *)conversation;

- (BOOL)containsUser:(ZMUser *)user conversation:(ZMConversation *)conversation;

@property (nonatomic, readonly) NSDate *firstTimeout;

- (NSSet *)userIDsInConversation:(ZMConversation *)conversation;

/// Removed the set of user & conversations that have a time-out before the given date, and returns the object IDs of those conversations.
- (NSSet *)pruneConversationsThatHaveTimedOutAfter:(NSDate *)pruneDate;

@end
