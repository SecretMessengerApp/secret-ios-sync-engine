// 


#import "ZMUser+Testing.h"

@implementation ZMUser (Testing)

- (void)assertMatchesUser:(MockUser *)user failureRecorder:(ZMTFailureRecorder *)failureRecorder;
{
    if (user == nil) {
        [failureRecorder recordFailure:@"ZMUser is <nil>"];
        return;
    }
    
    if(self.isSelfUser) {
        FHAssertEqualObjects(failureRecorder, self.emailAddress, user.email);
        FHAssertEqualObjects(failureRecorder, self.phoneNumber, user.phone);
    }
    
    FHAssertEqualObjects(failureRecorder, self.name, user.name);
    FHAssertEqualObjects(failureRecorder, self.remoteIdentifier, [user.identifier UUID]);
    FHAssertEqualObjects(failureRecorder, self.completeProfileAssetIdentifier, user.completeProfileAssetIdentifier);
}

@end
