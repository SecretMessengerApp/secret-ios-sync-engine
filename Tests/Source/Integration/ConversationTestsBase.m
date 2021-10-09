// 


#import "ConversationTestsBase.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"

@interface ConversationTestsBase()

@property (nonatomic, strong) NSMutableArray *testFiles;

@end

@implementation ConversationTestsBase

- (void)setUp{
    [super setUp];
    self.testFiles = [NSMutableArray array];
    [self setupGroupConversationWithOnlyConnectedParticipants];

    BackgroundActivityFactory.sharedFactory.activityManager = UIApplication.sharedApplication;
}

- (void)tearDown
{
    BackgroundActivityFactory.sharedFactory.activityManager = nil;

    [self.userSession.syncManagedObjectContext performGroupedBlockAndWait:^{
        [self.userSession.syncManagedObjectContext zm_teardownMessageObfuscationTimer];
    }];
    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
    
    [self.userSession.managedObjectContext zm_teardownMessageDeletionTimer];
    XCTAssert([self waitForAllGroupsToBeEmptyWithTimeout: 0.5]);
    self.groupConversationWithOnlyConnected = nil;

    for (NSURL *testFile in self.testFiles) {
        [NSFileManager.defaultManager removeItemAtURL:testFile error:nil];
    }
    [super tearDown];
}

- (NSURL *)createTestFile:(NSString *)name
{
    NSError *error;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *directory = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    XCTAssertNil(error);

    NSString *fileName = [NSString stringWithFormat:@"%@.dat", name];
    NSURL *fileURL = [directory URLByAppendingPathComponent:fileName].filePathURL;
    NSData *testData = [NSData secureRandomDataOfLength:256];
    XCTAssertTrue([testData writeToFile:fileURL.path atomically:YES]);

    [self.testFiles addObject:fileURL];

    return fileURL;
}

- (void)setDate:(NSDate *)date forAllEventsInMockConversation:(MockConversation *)conversation
{
    for(MockEvent *event in conversation.events) {
        event.time = date;
    }
}

- (void)setupGroupConversationWithOnlyConnectedParticipants
{
    [self createSelfUserAndConversation];
    [self createExtraUsersAndConversations];

    [self.mockTransportSession performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        
        NSDate *selfConversationDate = [NSDate dateWithTimeIntervalSince1970:1400157817];
        NSDate *connection1Date = [NSDate dateWithTimeInterval:500 sinceDate:selfConversationDate];
        NSDate *connection2Date = [NSDate dateWithTimeInterval:1000 sinceDate:connection1Date];
        NSDate *groupConversationDate = [NSDate dateWithTimeInterval:1000 sinceDate:connection2Date];
        
        [self setDate:selfConversationDate forAllEventsInMockConversation:self.selfConversation];
        [self setDate:connection1Date forAllEventsInMockConversation:self.selfToUser1Conversation];
        [self setDate:connection2Date forAllEventsInMockConversation:self.selfToUser2Conversation];
        [self setDate:groupConversationDate forAllEventsInMockConversation:self.groupConversation];
        
        self.connectionSelfToUser1.lastUpdate = connection1Date;
        self.connectionSelfToUser2.lastUpdate = connection2Date;

        self.groupConversationWithOnlyConnected = [session insertGroupConversationWithSelfUser:self.selfUser
                                                                                    otherUsers:@[self.user1, self.user2]];
        self.groupConversationWithOnlyConnected.creator = self.selfUser;
        [self.groupConversationWithOnlyConnected changeNameByUser:self.selfUser name:@"Group conversation with only connected participants"];
        
        self.emptyGroupConversation = [session insertGroupConversationWithSelfUser:self.selfUser otherUsers:@[]];
        self.emptyGroupConversation.creator = self.selfUser;
        [self.emptyGroupConversation changeNameByUser:self.selfUser name:@"Empty group conversation"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
}

- (void)testThatItSendsANotificationInConversation:(MockConversation *)mockConversation
                                    ignoreLastRead:(BOOL)ignoreLastRead
                        onRemoteMessageCreatedWith:(void(^)(void))createMessage
                                            verify:(void(^)(ZMConversation *))verifyConversation
{
    // given
    XCTAssertTrue([self login]);
    
    ZMConversation *conversation = [self conversationForMockConversation:mockConversation];
    
    // when
    ConversationChangeObserver *observer = [[ConversationChangeObserver alloc] initWithConversation:conversation];
    [observer clearNotifications];
    
    [self.mockTransportSession performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * __unused session) {
        createMessage();
    }];
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(observer.notifications.count, 1u);
    
    ConversationChangeInfo *note = observer.notifications.lastObject;
    XCTAssertNotNil(note);
    XCTAssertTrue(note.messagesChanged);
    XCTAssertFalse(note.participantsChanged);
    XCTAssertTrue(note.lastModifiedDateChanged);
    if(!ignoreLastRead) {
        XCTAssertTrue(note.unreadCountChanged);
    }
    XCTAssertFalse(note.connectionStateChanged);
    
    verifyConversation(conversation);
}

- (void)testThatItSendsANotificationInConversation:(MockConversation *)mockConversation
                        onRemoteMessageCreatedWith:(void(^)(void))createMessage
                                verifyWithObserver:(void(^)(ZMConversation *, ConversationChangeObserver *))verifyConversation;
{
    [self testThatItSendsANotificationInConversation:mockConversation
                                     afterLoginBlock:nil
                          onRemoteMessageCreatedWith:createMessage
                                  verifyWithObserver:verifyConversation];
}

- (void)testThatItSendsANotificationInConversation:(MockConversation *)mockConversation
                                   afterLoginBlock:(void(^)(void))afterLoginBlock
                        onRemoteMessageCreatedWith:(void(^)(void))createMessage
                                verifyWithObserver:(void(^)(ZMConversation *, ConversationChangeObserver *))verifyConversation;
{
    // given
    XCTAssertTrue([self login]);
    afterLoginBlock();
    WaitForAllGroupsToBeEmpty(0.5);
    ZMConversation *conversation = [self conversationForMockConversation:mockConversation];
    
    // when
    ConversationChangeObserver *observer = [[ConversationChangeObserver alloc] initWithConversation:conversation];
    [observer clearNotifications];
    
    [self.mockTransportSession performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * __unused session) {
        createMessage();
    }];
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    verifyConversation(conversation, observer);
}

- (BOOL)conversation:(ZMConversation *)conversation hasMessagesWithNonces:(NSArray *)nonces
{
    BOOL hasAllMessages = YES;
    for (NSUUID *nonce in nonces) {
        BOOL hasMessageWithNonce = [conversation.allMessages.allObjects containsObjectMatchingWithBlock:^BOOL(ZMMessage *msg) {
            return [msg.nonce isEqual:nonce];
        }];
        hasAllMessages &= hasMessageWithNonce;
    }
    return hasAllMessages;
}

- (void)testThatItAppendsMessageToConversation:(MockConversation *)mockConversation
                                     withBlock:(NSArray *(^)(MockTransportSession<MockTransportSessionObjectCreation> *session))appendMessages
                                        verify:(void(^)(ZMConversation *))verifyConversation
{
    // given
    XCTAssertTrue([self login]);
    
    ZMConversation *conversation = [self conversationForMockConversation:mockConversation];
    
    // when
    ConversationChangeObserver *observer = [[ConversationChangeObserver alloc] initWithConversation:conversation];
    [observer clearNotifications];
    
    __block NSArray *messsagesNonces;
    
    // expect
    XCTestExpectation *exp = [self expectationWithDescription:@"All messages received"];
    observer.notificationCallback = (ObserverCallback) ^(ConversationChangeInfo * __unused note) {
        BOOL hasAllMessages = [self conversation:conversation hasMessagesWithNonces:messsagesNonces];
        if (hasAllMessages) {
            [exp fulfill];
        }
    };
    
    // when
    [self.mockTransportSession performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * session) {
        messsagesNonces = appendMessages(session);
    }];
    XCTAssert([self waitForCustomExpectationsWithTimeout:0.5]);
    
    // then
    verifyConversation(conversation);
    
}

@end

