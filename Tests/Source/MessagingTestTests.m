// 


@import WireTransport;

#import "MessagingTest.h"

@interface MessagingTestTests : MessagingTest

@end


@implementation MessagingTestTests

- (void)testThatZMAssertQueueFailsWhenNotOnQueue
{
    NSOperationQueue *queue = [NSOperationQueue zm_serialQueueWithName:self.name];
    void(^doAssert)(void) = ^(void) { ZMAssertQueue(queue); };
    XCTAssertThrows(doAssert());
}

- (void)testThatWeCanCreateUUIDs;
{
    XCTAssertEqualObjects([NSUUID createUUID], [@"7BDA726A-13DC-4E46-A95D-2C872D340001" UUID]);
    XCTAssertEqualObjects([NSUUID createUUID], [@"7BDA726A-13DC-4E46-A95D-2C872D340002" UUID]);
    XCTAssertEqualObjects([NSUUID createUUID], [@"7BDA726A-13DC-4E46-A95D-2C872D340003" UUID]);
}

- (void)testArrayDifference
{
    NSArray *a1 = @[@4, @"foo", @"boo"];
    NSArray *a2 = @[@"foo", @"boo", @4];

    AssertArraysContainsSameObjects(a1, a2);
}

@end
