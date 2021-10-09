// 

@import WireRequestStrategy;
@import WireRequestStrategy;

@class NSManagedObjectContext;
@class ApplicationStatusDirectory;

@interface ZMLoginCodeRequestTranscoder : NSObject <RequestStrategy>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithGroupQueue:(id<ZMSGroupQueue>)groupQueue authenticationStatus:(ZMAuthenticationStatus *)authenticationStatus;

@end
