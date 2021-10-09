// 


@import Foundation;
@import CoreData;
@import WireRequestStrategy;

extern NSString * _Nullable const ConversationsPath;

extern NSString * _Nullable const ConversationServiceMessageAdd;
extern NSString * _Nullable const ConversationOtrMessageAdd;
extern NSString * _Nullable const ConversationUserConnection;

extern NSString * _Nullable const ConversationApplyToTestNotification;

@protocol ZMObjectStrategyDirectory;

@class ZMAuthenticationStatus;
@class SyncStatus;

@interface ZMConversationTranscoder : ZMAbstractRequestStrategy <ZMObjectStrategy>

- (instancetype _Nonnull)initWithManagedObjectContext:(NSManagedObjectContext * _Nullable)moc applicationStatus:(id<ZMApplicationStatus> _Nullable)applicationStatus NS_UNAVAILABLE;

- (instancetype _Nullable)initWithManagedObjectContext:(NSManagedObjectContext * _Nullable)managedObjectContext
                           applicationStatus:(id<ZMApplicationStatus> _Nullable)applicationStatus
                 localNotificationDispatcher:(id<PushMessageHandler> _Nullable)localNotificationDispatcher
                                  syncStatus:(SyncStatus * _Nullable)syncStatus;

@property (nonatomic) NSUInteger conversationPageSize;
@property (nonatomic, weak, readonly) id<PushMessageHandler> _Nullable localNotificationDispatcher;

@end
