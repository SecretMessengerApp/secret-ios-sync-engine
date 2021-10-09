// 


@import UIKit;
@import WireMockTransport;
@import WireDataModel;

#import "ZMUserSession.h"
#import "ZMUserSession+Internal.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"


@class BackgroundTests;

static NSTimeInterval zmMessageExpirationTimer = 0.3;


@interface BackgroundTests : IntegrationTest

@end


@implementation BackgroundTests

- (void)setUp
{
    [super setUp];
    
    [self createSelfUserAndConversation];
    [self createExtraUsersAndConversations];
}

- (void)tearDown
{
    self.mockTransportSession.disableEnqueueRequests = NO;
    [ZMMessage resetDefaultExpirationTime];
    
    [super tearDown];
}

- (void)testThatItSendsUILocalNotificationsForExpiredMessageRequestsWhenGoingToTheBackground
{
    // given
    XCTAssertTrue([self login]);
    self.mockTransportSession.responseGeneratorBlock = ^ZMTransportResponse *(ZMTransportRequest *request) {
        (void)request;
        return ResponseGenerator.ResponseNotCompleted;
    };
    
    ZMConversation *conversation = [self conversationForMockConversation:self.groupConversation];
    
    // when
    [self.userSession performChanges:^{
        [conversation appendMessageWithText:@"foo"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // background
    [self.application simulateApplicationDidEnterBackground];
    [self.application setBackground];
    
    [self.mockTransportSession expireAllBlockedRequests];
    WaitForAllGroupsToBeEmpty(0.5);

    // then
    XCTAssertEqual(self.notificationCenter.scheduledRequests.count, 1u);
}

- (void)testThatItSendsUILocalNotificationsForExpiredMessageNotPickedUpForRequestWhenGoingToTheBackground
{
    // given
    [ZMMessage setDefaultExpirationTime:zmMessageExpirationTimer];
    XCTAssertTrue([self login]);
    
    self.mockTransportSession.disableEnqueueRequests = YES;
    ZMConversation *conversation = [self conversationForMockConversation:self.groupConversation];
    
    // when
    [self.userSession performChanges:^{
        [conversation appendMessageWithText:@"foo"];
    }];
    
    // background
    [self.application simulateApplicationDidEnterBackground];
    [self.application setBackground];
    [self spinMainQueueWithTimeout:zmMessageExpirationTimer + 0.1];
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.notificationCenter.scheduledRequests.count, 1u);
}

- (void)testThatItDoesNotCreateNotificationsForMessagesInTheSelfConversation
{
    // given
    [ZMMessage setDefaultExpirationTime:zmMessageExpirationTimer];
    XCTAssertTrue([self login]);
    
    self.mockTransportSession.disableEnqueueRequests = YES;
    ZMConversation *conversation = [self conversationForMockConversation:self.selfConversation];
    
    // when
    [self.userSession performChanges:^{
        [conversation appendMessageWithText:@"foo"];
    }];
    
    // background
    [self.application simulateApplicationDidEnterBackground];
    [self spinMainQueueWithTimeout:zmMessageExpirationTimer + 0.1];
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(self.notificationCenter.scheduledRequests.count, 0u);
}

@end
