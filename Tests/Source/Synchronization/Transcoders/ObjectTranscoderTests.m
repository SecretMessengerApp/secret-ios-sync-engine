// 


#import "ObjectTranscoderTests.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"

@implementation ObjectTranscoderTests

- (void)setUp
{
    [super setUp];
    self.syncStrategy = [OCMockObject niceMockForClass:[ZMSyncStrategy class]];
    self.mockApplicationStatus = [[MockApplicationStatus alloc] init];
}

- (void)tearDown
{
    [(id)self.syncStrategy stopMocking];
    self.syncStrategy = nil;
    self.mockApplicationStatus = nil;
    [super tearDown];
}

@end
