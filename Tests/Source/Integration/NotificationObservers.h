// 


@import WireDataModel;

#import <WireSyncEngine/WireSyncEngine-Swift.h>

typedef void(^ObserverCallback)(NSObject *note);



@interface ChangeObserver : NSObject

@property (nonatomic, readonly) NSMutableArray *notifications;
@property (nonatomic, copy) ObserverCallback notificationCallback;

- (void)clearNotifications;

@end



@interface ConversationChangeObserver : ChangeObserver <ZMConversationObserver>
- (instancetype)initWithConversation:(ZMConversation *)conversation;

@end



@interface ConversationListChangeObserver : ChangeObserver <ZMConversationListObserver>
- (instancetype)initWithConversationList:(ZMConversationList *)conversationList;
@property (nonatomic) NSMutableArray *conversationChangeInfos;

@end



@interface UserChangeObserver : ChangeObserver <ZMUserObserver>
- (instancetype)initWithUser:(ZMUser *)user;
- (instancetype)initWithUser:(id<UserType>)user managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end



@interface MessageChangeObserver : ChangeObserver <ZMMessageObserver>
- (instancetype)initWithMessage:(ZMMessage *)message;

@end

