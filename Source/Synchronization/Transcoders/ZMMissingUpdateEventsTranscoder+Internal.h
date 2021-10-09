// 


@import Foundation;
@import WireRequestStrategy;
#import "ZMMissingUpdateEventsTranscoder.h"

extern NSUInteger const ZMMissingUpdateEventsTranscoderListPageSize;

@class ZMSimpleListRequestPaginator;

@interface ZMMissingUpdateEventsTranscoder ()

@property (nonatomic) ZMSimpleListRequestPaginator *listPaginator;
@property (nonatomic) NSUUID *lastUpdateEventID;

@property (nonatomic, readonly) BOOL isFetchingStreamForAPNS;
@property (nonatomic, readonly) BOOL isFetchingStreamInBackground;

@end
