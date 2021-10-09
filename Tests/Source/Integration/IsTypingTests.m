// 

@import WireDataModel;

#import "ZMTyping.h"
#import "ZMTypingUsers.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"


@interface IsTypingTests : IntegrationTest <ZMTypingChangeObserver>

@property (nonatomic) NSTimeInterval oldTimeout;
@property (nonatomic) NSMutableArray<TypingChange *> *notifications;

@end


@implementation IsTypingTests

- (void)setUp
{
    self.oldTimeout = ZMTypingDefaultTimeout;
    ZMTypingDefaultTimeout = 2;
    
    [super setUp];
    
    [self createSelfUserAndConversation];
    [self createExtraUsersAndConversations];
    
    self.notifications = [NSMutableArray array];
}

- (void)tearDown
{
    ZMTypingDefaultTimeout = self.oldTimeout;
    [super tearDown];
}

- (void)typingDidChangeWithConversation:(ZMConversation *)conversation typingUsers:(NSSet<ZMUser *> *)typingUsers
{
    [self.notifications addObject:[[TypingChange alloc] initWithConversation:conversation typingUsers:typingUsers]];
}

- (void)testThatItSendsTypingNotifications;
{
    XCTAssertTrue([self login]);
    
    ZMConversation *conversation = [self conversationForMockConversation:self.groupConversation];
    ZMUser *user1 = [self userForMockUser:self.user1];
    id token = [conversation addTypingObserver:self];
    
    XCTAssertEqual(conversation.typingUsers.count, 0u);
    
    [self.mockTransportSession sendIsTypingEventForConversation:self.groupConversation user:self.user1 started:YES];
    WaitForAllGroupsToBeEmpty(0.5);
    
    XCTAssertEqual(self.notifications.count, 1u);
    TypingChange *note = self.notifications.firstObject;
    XCTAssertEqual(note.conversation, conversation);
    XCTAssertEqual(note.typingUsers.count, 1u);
    XCTAssertEqual(note.typingUsers.anyObject, user1);
    XCTAssertEqual(conversation.typingUsers.count, 1u);
    XCTAssertEqual(conversation.typingUsers.anyObject, user1);
    
    token = nil;
}
    
- (void)testThatItSendsTypingNotificationsForConversation;
{
    XCTAssertTrue([self login]);
    
    ZMConversation *conversation = [self conversationForMockConversation:self.groupConversation];
    ZMConversation *otherConversation = [self conversationForMockConversation:self.selfToUser1Conversation];
    id token = [otherConversation addTypingObserver:self];
    
    XCTAssertEqual(conversation.typingUsers.count, 0u);
    
    [self.mockTransportSession sendIsTypingEventForConversation:self.groupConversation user:self.user1 started:YES];
    WaitForAllGroupsToBeEmpty(0.5);
    
    XCTAssertEqual(self.notifications.count, 0u);
    
    token = nil;
}
    
- (void)testThatItTypingStatusTimesOut;
{
    XCTAssertTrue([self login]);
    
    ZMConversation *conversation = [self conversationForMockConversation:self.groupConversation];
    id token = [conversation addTypingObserver:self];
    
    XCTAssertEqual(conversation.typingUsers.count, 0u);
    
    [self.mockTransportSession sendIsTypingEventForConversation:self.groupConversation user:self.user1 started:YES];
    WaitForAllGroupsToBeEmpty(0.5);
    
    XCTAssertEqual(self.notifications.count, 1u);
    [self.notifications removeAllObjects];
    
    [self spinMainQueueWithTimeout:ZMTypingDefaultTimeout + 1];
    
    XCTAssertEqual(self.notifications.count, 1u);
    TypingChange *note = self.notifications.firstObject;
    XCTAssertEqual(note.conversation, conversation);
    XCTAssertEqual(note.typingUsers.count, 0u);
    XCTAssertEqual(conversation.typingUsers.count, 0u);
    
    token = nil;
}

- (void)testThatItResetsIsTypingWhenATypingUserSendsAMessage
{
    // given
    XCTAssertTrue([self login]);
    
    ZMConversation *conversation = [self conversationForMockConversation:self.groupConversation];
    id token = [conversation addTypingObserver:self];
    
    XCTAssertEqual(conversation.typingUsers.count, 0u);
    
    // when  
    [self.mockTransportSession sendIsTypingEventForConversation:self.groupConversation user:self.user1 started:YES];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.notifications.count, 1u);
    XCTAssertEqual(conversation.typingUsers.count, 1u);
    [self.notifications removeAllObjects];
    
    // when
    [self.mockTransportSession performRemoteChanges:^(ZM_UNUSED id session) {
        ZMGenericMessage *message = [ZMGenericMessage messageWithContent:[ZMText textWith:@"text text" mentions:@[] linkPreviews:@[] replyingTo:nil] nonce:NSUUID.createUUID];
        [self.groupConversation encryptAndInsertDataFromClient:self.user1.clients.anyObject toClient:self.selfUser.clients.anyObject data:message.data];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(conversation.typingUsers.count, 0u);
    
    token = nil;
}

- (void)testThatIt_DoesNot_ResetIsTypingWhenA_DifferentUser_ThanTheTypingUserSendsAMessage
{
    // given
    XCTAssertTrue([self login]);
    
    ZMConversation *conversation = [self conversationForMockConversation:self.groupConversation];
    id token = [conversation addTypingObserver:self];
    
    XCTAssertEqual(conversation.typingUsers.count, 0u);
    
    // when
    [self.mockTransportSession sendIsTypingEventForConversation:self.groupConversation user:self.user2 started:YES];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.notifications.count, 1u);
    XCTAssertEqual(conversation.typingUsers.count, 1u);
    [self.notifications removeAllObjects];
    
    // when
    [self.mockTransportSession performRemoteChanges:^(ZM_UNUSED id session) {
        ZMGenericMessage *message = [ZMGenericMessage messageWithContent:[ZMText textWith:@"text text" mentions:@[] linkPreviews:@[] replyingTo:nil] nonce:NSUUID.createUUID];
        [self.groupConversation encryptAndInsertDataFromClient:self.user1.clients.anyObject toClient:self.selfUser.clients.anyObject data:message.data];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(conversation.typingUsers.count, 1u);
    token = nil;
}

@end
