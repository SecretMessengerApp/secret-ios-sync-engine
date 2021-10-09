// 


@import Foundation;
@import WireRequestStrategy;
@import WireRequestStrategy;

@protocol UserInfoParser;
@class NSManagedObjectContext;
@class ZMAuthenticationStatus;


NS_ASSUME_NONNULL_BEGIN;

@interface ZMLoginTranscoder : NSObject <RequestStrategy, TearDownCapable>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithGroupQueue:(id<ZMSGroupQueue>)groupQueue
              authenticationStatus:(ZMAuthenticationStatus *)authenticationStatus;

@end

NS_ASSUME_NONNULL_END;
