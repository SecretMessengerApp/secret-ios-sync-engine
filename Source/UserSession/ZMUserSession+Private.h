//


@import WireUtilities;
@import WireTransport;
@import WireDataModel;

@class OperationStatus;
@class ManagedObjectContextChangeObserver;
@class NotificationDispatcher;
@class LocalNotificationDispatcher;
@class AccountStatus;
@class ApplicationStatusDirectory;
@class UserExpirationObserver;

@protocol MediaManagerType;
@protocol TransportSessionType;

#import "ZMUserSession.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZMUserSession ()

// Status flags.

@property (nonatomic) BOOL networkIsOnline;
@property (nonatomic) BOOL isPerformingSync;
@property (nonatomic) BOOL pushChannelIsOpen;
@property (nonatomic) BOOL didNotifyThirdPartyServices;

@end

@interface ZMUserSession (Private)

@property (nonatomic, readonly) id<TransportSessionType> transportSession;
@property (nonatomic, readonly) NSManagedObjectContext *searchManagedObjectContext;
@property (nonatomic, readonly) OperationStatus *operationStatus;
@property (nonatomic, readonly) AccountStatus *accountStatus;
@property (nonatomic, readonly) ApplicationStatusDirectory *applicationStatusDirectory;
@property (nonatomic, readonly) NotificationDispatcher *notificationDispatcher;
@property (nonatomic, readonly) LocalNotificationDispatcher *localNotificationDispatcher;
@property (nonatomic, nullable) ManagedObjectContextChangeObserver *messageReplyObserver;
@property (nonatomic, nullable) ManagedObjectContextChangeObserver *likeMesssageObserver;
@property (nonatomic, nonnull)  UserExpirationObserver *userExpirationObserver;
@property (nonatomic, readonly) id<MediaManagerType> mediaManager;

- (void)tearDown;

@end

NS_ASSUME_NONNULL_END
