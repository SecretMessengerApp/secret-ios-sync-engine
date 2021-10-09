// 


@import Foundation;

@class ZMUpdateEvent;

@protocol ZMUpdateEventConsumer <NSObject>

- (void)consumeUpdateEvents:(NSArray<ZMUpdateEvent *>* _Nonnull)updateEvents NS_SWIFT_NAME(consume(updateEvents:));

- (void)consumeHugeUpdateEvents:(NSArray<ZMUpdateEvent *>* _Nonnull)updateEvents NS_SWIFT_NAME(consumeHuge(updateEvents:));

@end

@protocol ZMUpdateEventsFlushableCollection <NSObject>

/// process all events in the buffer
- (void)processAllEventsInBuffer;

@end


@interface ZMUpdateEventsBuffer : NSObject <ZMUpdateEventsFlushableCollection>

- (instancetype _Nonnull )initWithUpdateEventConsumer:(id <ZMUpdateEventConsumer> _Nonnull)eventConsumer isHuge:(BOOL) ishuge;

/// discard all events in the buffer
- (void)discardAllUpdateEvents;

/// discard the event with this identifier
- (void)discardUpdateEventWithIdentifier:(NSUUID *_Nonnull)eventIdentifier;

- (void)addUpdateEvent:(ZMUpdateEvent *_Nonnull)event;

- (NSArray *_Nonnull)updateEvents;

- (BOOL)isHuge;

@end
