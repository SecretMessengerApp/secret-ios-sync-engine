// 


@import WireSyncEngine;

@import WireMockTransport;

@interface ZMUser (Testing)

- (void)assertMatchesUser:(MockUser *)user failureRecorder:(ZMTFailureRecorder *)failureRecorder;

@end
