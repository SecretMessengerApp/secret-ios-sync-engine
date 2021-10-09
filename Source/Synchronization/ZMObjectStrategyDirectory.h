// 

@import WireRequestStrategy;
@import Foundation;
#import "ZMUpdateEventsBuffer.h"

@class ZMConnectionTranscoder;
@class ZMUserTranscoder;
@class ZMSelfStrategy;
@class ZMConversationTranscoder;
@class ZMMissingUpdateEventsTranscoder;
@class ZMMissingHugeUpdateEventsTranscoder;
@class ZMRegistrationTranscoder;
@class ZMLastUpdateEventIDTranscoder;
@class ZMPhoneNumberVerificationTranscoder;

@protocol ZMUpdateEventsFlushableCollection;



@protocol ZMObjectStrategyDirectory <NSObject, ZMUpdateEventsFlushableCollection>

@property (nonatomic, readonly) ZMConnectionTranscoder *connectionTranscoder;
@property (nonatomic, readonly) ZMUserTranscoder *userTranscoder;
@property (nonatomic, readonly) ZMSelfStrategy *selfStrategy;
@property (nonatomic, readonly) ZMConversationTranscoder *conversationTranscoder;
@property (nonatomic, readonly) ClientMessageTranscoder *clientMessageTranscoder;
@property (nonatomic, readonly) ZMMissingUpdateEventsTranscoder *missingUpdateEventsTranscoder;
@property (nonatomic, readonly) ZMMissingHugeUpdateEventsTranscoder *missingHugeUpdateEventsTranscoder;
@property (nonatomic, readonly) ZMLastUpdateEventIDTranscoder *lastUpdateEventIDTranscoder;
@property (nonatomic, readonly) NSManagedObjectContext *moc;

@end
