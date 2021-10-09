// 


@import Foundation;
@import WireRequestStrategy;
#import "ZMMissingHugeUpdateEventsTranscoder.h"

extern NSUInteger const ZMMissingUpdateEventsTranscoderListPageSize;

@class ZMSimpleListRequestPaginator;

@interface ZMMissingHugeUpdateEventsTranscoder ()

@property (nonatomic) ZMSimpleListRequestPaginator *listPaginator;
@property (nonatomic) NSUUID *lastHugeUpdateEventID;

@property (nonatomic, readonly) BOOL isFetchingStreamForAPNS;
@property (nonatomic, readonly) BOOL isFetchingStreamInBackground;

@end
