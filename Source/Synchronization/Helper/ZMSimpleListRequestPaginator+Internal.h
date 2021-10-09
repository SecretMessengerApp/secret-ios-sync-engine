//

#import "ZMSimpleListRequestPaginator.h"
#import "ZMSingleRequestSync.h"

@interface ZMSimpleListRequestPaginator (Internal) <ZMSingleRequestTranscoder>

@property (nonatomic) ZMSingleRequestSync *singleRequestSync;

@end
