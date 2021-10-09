// 


@import Foundation;
@import CoreData;

@class ZMUser;
@class ZMConversation;



/// This class is used to track typing users per conversation on the UI context.
///
/// The changes on the sync side are pushed into this class to keep it up-to-date.
@interface ZMTypingUsers : NSObject

- (void)updateTypingUsers:(NSSet<ZMUser *> *)typingUsers inConversation:(ZMConversation *)conversation;

- (NSSet *)typingUsersInConversation:(ZMConversation *)conversation;

@end



@interface NSManagedObjectContext (ZMTypingUsers)

@property (nonatomic, readonly) ZMTypingUsers *typingUsers;

@end


@interface ZMConversation (ZMTypingUsers)

- (void)setIsTyping:(BOOL)isTyping;
- (NSSet *)typingUsers;

@end
