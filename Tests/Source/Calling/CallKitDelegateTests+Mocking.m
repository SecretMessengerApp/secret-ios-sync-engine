//

#import "CallKitDelegateTests+Mocking.h"
#import "ZMUserSession+Internal.h"
@import WireSyncEngine;
@import OCMock;

@implementation CallKitDelegateTestsMocking

+ (void)mockUserSession:(id)userSession
{    
    [(id)[userSession stub] performChanges:[OCMArg checkWithBlock:^BOOL(id param) {
        void (^passedBlock)(void) = param;
        passedBlock();
        return YES;
    }]];
}

+ (CXCall *)mockCallWithUUID:(NSUUID *)uuid outgoing:(BOOL)outgoing
{
    id mockCall = [OCMockObject niceMockForClass:CXCall.class];
    
    [(CXCall *)[[mockCall stub] andReturn:uuid] UUID];
    [(CXCall *)[[mockCall stub] andReturnValue:@(outgoing)] isOutgoing];
    
    return mockCall;
}

+ (void)stopMockingMock:(NSObject *)mock
{
    [(OCMockObject* )mock stopMocking];
}

@end
