// 

@import WireDataModel;

#import "MessagingTest.h"
#import "ZMTypingUsers.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>
#import "WireSyncEngine_iOS_Tests-Swift.h"


@interface ZMTypingUsersTests : MessagingTest

@property (nonatomic) ZMTypingUsers *sut;

@property (nonatomic) ZMUser *user1;
@property (nonatomic) ZMUser *user2;
@property (nonatomic) ZMUser *selfUser;
@property (nonatomic) ZMConversation *conversation1;
@property (nonatomic) ZMConversation *conversation2;

@end

@interface ZMConversationTest_TypingUser : MessagingTest

@end

@implementation ZMTypingUsersTests

- (void)setUp
{
    [super setUp];

    self.user1 = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    self.user1.name = @"Hans";
    self.user2 = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    self.user2.name = @"Gretel";
    self.selfUser = [ZMUser selfUserInContext:self.uiMOC];
    self.selfUser.name = @"Myself";
    self.conversation1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    self.conversation1.userDefinedName = @"A Walk in the Forest";
    self.conversation2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    self.conversation2.userDefinedName = @"The Great Escape";
    
    self.sut = [[ZMTypingUsers alloc] init];
    
    XCTAssert([self.uiMOC saveOrRollback]);
}

- (void)tearDown
{
    self.sut = nil;
    self.user1 = nil;
    self.user2 = nil;
    self.conversation1 = nil;
    self.conversation2 = nil;
    
    [super tearDown];
}

- (void)testThatItReturnsAnEmptySetByDefault;
{
    XCTAssertEqualObjects([self.sut typingUsersInConversation:self.conversation1], [NSSet set]);
}

- (void)testThatItReturnsTheTypingUsers;
{
    // given
    NSSet *users = [NSSet setWithObjects:self.user1, self.user2, nil];
    
    // when
    [self.sut updateTypingUsers:users inConversation:self.conversation1];
    
    // then
    XCTAssertEqualObjects([self.sut typingUsersInConversation:self.conversation1], users);
    XCTAssertEqualObjects([self.sut typingUsersInConversation:self.conversation2], [NSSet set]);
}

- (void)testThatItUpdatesTheTypingUsers;
{
    // given
    NSSet *usersA = [NSSet setWithObjects:self.user1, self.user2, nil];
    NSSet *usersB = [NSSet setWithObjects:self.user1, nil];
    
    // when
    [self.sut updateTypingUsers:usersA inConversation:self.conversation1];
    [self.sut updateTypingUsers:usersB inConversation:self.conversation1];
    
    // then
    XCTAssertEqualObjects([self.sut typingUsersInConversation:self.conversation1], usersB);
    XCTAssertEqualObjects([self.sut typingUsersInConversation:self.conversation2], [NSSet set]);
}

- (void)testThatItUpdatesMultipleConversations;
{
    // given
    NSSet *usersA = [NSSet setWithObjects:self.user1, nil];
    NSSet *usersB = [NSSet setWithObjects:self.user2, nil];
    
    // when
    [self.sut updateTypingUsers:usersA inConversation:self.conversation1];
    [self.sut updateTypingUsers:usersB inConversation:self.conversation2];
    
    // then
    XCTAssertEqualObjects([self.sut typingUsersInConversation:self.conversation1], usersA);
    XCTAssertEqualObjects([self.sut typingUsersInConversation:self.conversation2], usersB);
}

- (void)testThatItAddsAnInstanceToTheUIContext;
{
    // when
    ZMTypingUsers *sut = self.uiMOC.typingUsers;
    
    // then
    XCTAssertTrue([sut isKindOfClass:ZMTypingUsers.class]);
    XCTAssertEqual(sut, self.uiMOC.typingUsers);
}

- (void)testThatItDoesNotAddAnInstanceToTheSyncContext;
{
    [self.syncMOC performGroupedBlockAndWait:^{
        XCTAssertNil(self.syncMOC.typingUsers);
    }];
}

@end



@implementation ZMConversationTest_TypingUser


- (void)testThatItCreatesANotificationWhenCallingSetTyping
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];

    // then
    XCTestExpectation *expectation = [self expectationWithDescription:@"Notification"];
    id token = [NotificationInContext addObserverWithName:ZMConversation.typingChangeNotificationName
                                                  context:self.uiMOC.notificationContext
                                                   object:nil
                                                    queue:nil using:^(NotificationInContext * notification) {
                                                        XCTAssertEqual(notification.object, conversation);
                                                        XCTAssertEqual(notification.userInfo[@"isTyping"], @(YES));
                                                        [expectation fulfill];
                                                    }];
    
    // when
    [conversation setIsTyping:YES];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // teardown
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
    token = nil;
}

@end


