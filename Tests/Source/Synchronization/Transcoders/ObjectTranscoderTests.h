// 


#import "MessagingTest.h"
#import "ZMSyncStrategy.h"


@class MockApplicationStatus;


@interface ObjectTranscoderTests : MessagingTest

@property (nonatomic) ZMSyncStrategy *syncStrategy;
@property (nonatomic) MockApplicationStatus *mockApplicationStatus;

@end
