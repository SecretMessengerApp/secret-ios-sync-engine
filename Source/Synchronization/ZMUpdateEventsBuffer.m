// 

@import WireTransport;
#import "ZMUpdateEventsBuffer.h"

@interface ZMUpdateEventsBuffer ()

@property (nonatomic, readonly, weak) id<ZMUpdateEventConsumer> consumer;
@property (nonatomic, readonly) NSMutableArray *bufferedEvents;
@property (nonatomic, readonly) BOOL isHuge;
@end




@implementation ZMUpdateEventsBuffer

- (instancetype)initWithUpdateEventConsumer:(id<ZMUpdateEventConsumer>)eventConsumer isHuge:(BOOL) ishuge
{
    self = [super self];
    if(self) {
        _bufferedEvents = [NSMutableArray array];
        _consumer = eventConsumer;
        _isHuge = ishuge;
    }
    return self;
}

- (void)addUpdateEvent:(ZMUpdateEvent *)event
{
    [self.bufferedEvents addObject:event];
}

- (void)processAllEventsInBuffer
{
    self.isHuge ? [self processHugeEvents] : [self processEvents];
    [self.bufferedEvents removeAllObjects];
}

- (void)processEvents {
    [self.consumer consumeUpdateEvents:self.bufferedEvents];
}

- (void)processHugeEvents {
    [self.consumer consumeHugeUpdateEvents:self.bufferedEvents];
}

- (void)discardAllUpdateEvents
{
    [self.bufferedEvents removeAllObjects];
}

- (void)discardUpdateEventWithIdentifier:(NSUUID *)eventIdentifier
{
    NSUInteger index = [self.bufferedEvents indexOfObjectPassingTest:^BOOL(ZMUpdateEvent *obj, NSUInteger __unused idx, BOOL * __unused stop) {
        return [obj.uuid isEqual:eventIdentifier];
    }];
    if(index != NSNotFound) {
        [self.bufferedEvents removeObjectAtIndex:index];
    }
}

- (NSArray *)updateEvents
{
    return self.bufferedEvents;
}

@end
