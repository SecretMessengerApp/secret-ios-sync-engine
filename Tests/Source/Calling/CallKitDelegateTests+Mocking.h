//

@import Foundation;
@import WireSyncEngine;
@import CallKit;

NS_ASSUME_NONNULL_BEGIN

@interface CallKitDelegateTestsMocking: NSObject
+ (void)mockUserSession:(id)userSession;
+ (CXCall *)mockCallWithUUID:(NSUUID *)uuid outgoing:(BOOL)outgoing;
+ (void)stopMockingMock:(NSObject *)Mock;

@end

NS_ASSUME_NONNULL_END
