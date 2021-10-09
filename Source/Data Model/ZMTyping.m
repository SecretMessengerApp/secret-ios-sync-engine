// 


@import WireSystem;
@import WireUtilities;
@import WireDataModel;

#import "ZMTyping.h"
#import "ZMTypingUsersTimeout.h"
#import "ZMTypingUsers.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>


#if DEBUG
NSTimeInterval ZMTypingDefaultTimeout = 60;
#else
const NSTimeInterval ZMTypingDefaultTimeout = 60;
#endif
const NSTimeInterval ZMTypingRelativeSendTimeout = 5;



@interface ZMTyping () <ZMTimerClient>

@property (nonatomic) NSManagedObjectContext *userInterfaceContext;
@property (nonatomic) NSManagedObjectContext *syncContext;
@property (nonatomic) ZMTypingUsersTimeout *typingUserTimeout;

@property (nonatomic) ZMTimer *expirationTimer;
@property (nonatomic) NSDate *nextPruneDate;

@property (nonatomic) BOOL needsTearDown;

@end



@implementation ZMTyping

- (instancetype)initWithUserInterfaceManagedObjectContext:(NSManagedObjectContext *)uiMOC syncManagedObjectContext:(NSManagedObjectContext *)syncMOC;
{
    self = [super init];
    if (self) {
        self.needsTearDown = YES;
        self.userInterfaceContext = uiMOC;
        self.syncContext = syncMOC;
        self.timeout = ZMTypingDefaultTimeout;
        self.typingUserTimeout = [[ZMTypingUsersTimeout alloc] init];
    }
    return self;
}

- (void)tearDown;
{
    self.needsTearDown = NO;
    [self.expirationTimer cancel];
    self.expirationTimer = nil;
}

- (void)dealloc
{
    Require(! self.needsTearDown);
}

- (void)setIsTyping:(BOOL)isTyping forUser:(ZMUser *)user inConversation:(ZMConversation *)conversation;
{
    BOOL const wasTyping = [self.typingUserTimeout containsUser:user conversation:conversation];
    if (isTyping) {
        [self.typingUserTimeout addUser:user conversation:conversation withTimeout:[NSDate dateWithTimeIntervalSinceNow:self.timeout]];
    }
    if (wasTyping != isTyping) {
        if (! isTyping) {
            [self.typingUserTimeout removeUser:user conversation:conversation];
        }
        [self sendNotificationForConversation:conversation];
    }
    [self updateExpirationWithDate:self.typingUserTimeout.firstTimeout];
}

- (void)sendNotificationForConversation:(ZMConversation *)conversation
{
    NSSet *userIds = [self.typingUserTimeout userIDsInConversation:conversation];
    NSManagedObjectID *convID = conversation.objectID;
    
    [self.userInterfaceContext performGroupedBlock:^{
        ZMConversation *conv = (id) [self.userInterfaceContext objectWithID:convID];
        NSSet *users = [userIds mapWithBlock:^id(NSManagedObjectID *moid) {
            return [self.userInterfaceContext objectWithID:moid];
        }];
        
        [self.userInterfaceContext.typingUsers updateTypingUsers:users inConversation:conv];
        [conv notifyTypingWithTypingUsers:users];
    }];
}

- (void)updateExpirationWithDate:(NSDate *)date;
{
    if ((date == self.nextPruneDate) || [date isEqualToDate:self.nextPruneDate]) {
        return;
    }
    
    [self.expirationTimer cancel];
    self.expirationTimer = nil;
    self.nextPruneDate = date;
    
    if (self.nextPruneDate != nil) {
        self.expirationTimer = [ZMTimer timerWithTarget:self];
        [self.expirationTimer fireAtDate:self.nextPruneDate];
    }
}

- (void)timerDidFire:(ZMTimer *)timer;
{
    if (timer == self.expirationTimer) {
        [self.syncContext performGroupedBlock:^{
            NSSet *conversationIDs = [self.typingUserTimeout pruneConversationsThatHaveTimedOutAfter:[NSDate date]];
            for (NSManagedObjectID *moid in conversationIDs) {
                ZMConversation *conversation = (id) [self.syncContext objectWithID:moid];
                [self sendNotificationForConversation:conversation];
            }
            [self updateExpirationWithDate:self.typingUserTimeout.firstTimeout];
        }];
    }
}

@end
