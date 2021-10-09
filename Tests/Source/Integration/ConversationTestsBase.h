// 

@import WireTransport;
@import WireMockTransport;
@import WireSyncEngine;
@import WireDataModel;

#import "ZMUserSession.h"
#import "ZMUserSession+Internal.h"
#import "NotificationObservers.h"
#import "ZMConversationTranscoder+Internal.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>
#import "IntegrationTest.h"


@interface ConversationTestsBase : IntegrationTest

- (void)testThatItAppendsMessageToConversation:(MockConversation *)mockConversation
                                     withBlock:(NSArray *(^)(MockTransportSession<MockTransportSessionObjectCreation> *session))appendMessages
                                        verify:(void(^)(ZMConversation *))verifyConversation;

- (void)testThatItSendsANotificationInConversation:(MockConversation *)mockConversation
                                    ignoreLastRead:(BOOL)ignoreLastRead
                        onRemoteMessageCreatedWith:(void(^)(void))createMessage
                                            verify:(void(^)(ZMConversation *))verifyConversation;

- (void)testThatItSendsANotificationInConversation:(MockConversation *)mockConversation
                        onRemoteMessageCreatedWith:(void(^)(void))createMessage
                                verifyWithObserver:(void(^)(ZMConversation *, ConversationChangeObserver *))verifyConversation;

- (void)testThatItSendsANotificationInConversation:(MockConversation *)mockConversation
                                   afterLoginBlock:(void(^)(void))afterLoginBlock
                        onRemoteMessageCreatedWith:(void(^)(void))createMessage
                                verifyWithObserver:(void(^)(ZMConversation *, ConversationChangeObserver *))verifyConversation;

- (NSURL *)createTestFile:(NSString *)name;

@property (nonatomic) MockConversation *groupConversationWithOnlyConnected;
@property (nonatomic) MockConversation *emptyGroupConversation;

@end
