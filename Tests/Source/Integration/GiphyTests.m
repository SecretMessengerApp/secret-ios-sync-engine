// 

#import "ZMUserSession.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"

@interface GiphyTests : IntegrationTest

@end

@implementation GiphyTests

- (void)setUp
{
    [super setUp];
    
    [self createSelfUserAndConversation];
}

- (void)testThatItSendsARequestAndInvokesCallback {
    
    // given
    XCTAssertTrue([self login]);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"callback called"];
    NSArray *expectedPayload = @[@"bar"];
    NSString *path = @"/foo/bar/baz";

    WaitForAllGroupsToBeEmpty(0.5);
    [self.mockTransportSession resetReceivedRequests];
    
    ZM_WEAK(self);
    self.mockTransportSession.responseGeneratorBlock = ^ZMTransportResponse *(ZMTransportRequest *request){
        ZM_STRONG(self);
        if([request.path hasPrefix:@"/proxy/giphy"]) {
            XCTAssertEqualObjects(request.path, @"/proxy/giphy/foo/bar/baz");
            XCTAssertEqual(request.method, ZMMethodGET);
            XCTAssertTrue(request.needsAuthentication);
            
            return [ZMTransportResponse responseWithPayload:expectedPayload HTTPStatus:202 transportSessionError:nil];
        }
    };
    
    // when
    void (^callback)(NSData *, NSHTTPURLResponse *, NSError *) = ^(NSData *data,NSHTTPURLResponse *response, NSError *error) {
        XCTAssertEqualObjects(data, [ZMTransportCodec encodedTransportData:expectedPayload]);
        XCTAssertEqual(response.statusCode, 202);
        XCTAssertNil(error);
        [expectation fulfill];
    };
    [self.userSession proxiedRequestWithPath:path method:ZMMethodGET type:ProxiedRequestTypeGiphy callback:callback];
    WaitForAllGroupsToBeEmpty(0.5);
    [self spinMainQueueWithTimeout:0.2];
    
    // then
    XCTAssertEqual(self.mockTransportSession.receivedRequests.count, 1u);
    ZMTransportRequest *request = self.mockTransportSession.receivedRequests.firstObject;
    XCTAssertEqualObjects(request.path, [@"/proxy/giphy" stringByAppendingString:path]);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
}

@end
