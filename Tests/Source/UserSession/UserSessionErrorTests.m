// 


#import "MessagingTest.h"
#import "NSError+ZMUserSessionInternal.h"



@interface UserSessionErrorTests : MessagingTest
@end



@implementation UserSessionErrorTests

- (void)testOtherError;
{
    NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:5 userInfo:nil];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.userSessionErrorCode, ZMUserSessionNoError);
}

- (void)testNeedsCredentials;
{
    NSError *error = [NSError userSessionErrorWithErrorCode:ZMUserSessionNeedsCredentials userInfo:nil];
    XCTAssertNotNil(error);
    XCTAssertEqual(error.userSessionErrorCode, ZMUserSessionNeedsCredentials);
}

@end
