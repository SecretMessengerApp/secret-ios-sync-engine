// 


#import <Foundation/Foundation.h>

typedef void(^ZMHotFixPatchCode)(NSManagedObjectContext *moc);

/// A patch to run on the data
@interface ZMHotFixPatch : NSObject

+ (instancetype)patchWithVersion:(NSString *)version patchCode:(ZMHotFixPatchCode)code;

/// Which version introduced this patch
@property (nonatomic, readonly, copy) NSString *version;
/// The code to apply the patch
@property (nonatomic, readonly, copy) ZMHotFixPatchCode code;

@end



/// List of hot fixes to run on the data organized by version
@interface ZMHotFixDirectory : NSObject

/// List of ZMHotFixPatch that can be applied, ordered by version
@property (nonatomic, readonly) NSArray *patches;

@end
