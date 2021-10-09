// 


@import Foundation;

@class ZMHotFixDirectory;

extern NSString * const ZMSkipHotfix;



@interface ZMHotFix : NSObject

- (instancetype)initWithSyncMOC:(NSManagedObjectContext *)syncMOC;

/// This method is supposed to be called once on startup
/// It checks if there is a last version stored in the persistentStore and then applies patches (once) for older versions and saves the current version in the persistentStore
- (void)applyPatches;


@end


@interface ZMHotFix (Testing)

- (instancetype)initWithHotFixDirectory:(ZMHotFixDirectory *)hotFixDirectory syncMOC:(NSManagedObjectContext *)syncMOC;
- (void)applyPatchesForCurrentVersion:(NSString *)currentVersion;

@end



