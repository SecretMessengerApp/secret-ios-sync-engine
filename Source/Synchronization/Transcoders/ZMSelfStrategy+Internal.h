// 


#import "ZMSelfStrategy.h"

extern NSTimeInterval ZMSelfStrategyPendingValidationRequestInterval;


@class ZMTimedSingleRequestSync;
@class ZMClientRegistrationStatus;

@interface ZMSelfStrategy ()

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)applicationStatus
                    clientRegistrationStatus:(ZMClientRegistrationStatus *)clientRegistrationStatus
                                  syncStatus:(SyncStatus *)syncStatus
                          upstreamObjectSync:(ZMUpstreamModifiedObjectSync *)upstreamObjectSync NS_DESIGNATED_INITIALIZER;


@property (nonatomic, readonly) ZMTimedSingleRequestSync *timedDownstreamSync;

@end
