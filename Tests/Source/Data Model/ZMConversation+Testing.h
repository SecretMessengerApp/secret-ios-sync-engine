// 


@import WireSyncEngine;

@import WireMockTransport;

@interface ZMConversation (Testing)

- (void)assertMatchesConversation:(MockConversation *)conversation failureRecorder:(ZMTFailureRecorder *)failureRecorder;

/// Creates enough unread messages to make the unread count match the required count
- (void)setUnreadCount:(NSUInteger)count;

/// Adds a system message for a missed call and make it unread by setting the timestamp past the last read
- (void)addUnreadMissedCall;

/// Adds an unread unsent message in the conversation
- (void)setHasExpiredMessage:(BOOL)hasUnreadUnsentMessage;


@end

