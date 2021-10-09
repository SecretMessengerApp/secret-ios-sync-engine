// 


@import CoreData;
@import Foundation;
@import WireRequestStrategy;
#import "ZMConnectionTranscoder.h"

extern NSUInteger ZMConnectionTranscoderPageSize;

@interface ZMConnectionTranscoder (UpstreamTranscoder) <ZMUpstreamTranscoder>
@end

@interface ZMConnectionTranscoder (DownstreamSync) <ZMDownstreamTranscoder>
@end
