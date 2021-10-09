// 


@import WireUtilities;
@import WireTransport;
@import WireDataModel;
@import WireRequestStrategy;

#import "ZMHotFix.h"
#import "ZMHotFixDirectory.h"
#import "ZMUserSession.h"

static NSString* ZMLogTag ZM_UNUSED = @"HotFix";
static NSString * const LastSavedVersionKey = @"lastSavedVersion";
NSString * const ZMSkipHotfix = @"ZMSkipHotfix";

@interface ZMHotFix ()
@property (nonatomic) ZMHotFixDirectory *hotFixDirectory;
@property (nonatomic) NSManagedObjectContext *syncMOC;
@end


@implementation ZMHotFix


- (instancetype)initWithSyncMOC:(NSManagedObjectContext *)syncMOC
{
    return [self initWithHotFixDirectory:nil syncMOC:syncMOC];
}

- (instancetype)initWithHotFixDirectory:(ZMHotFixDirectory *)hotFixDirectory syncMOC:(NSManagedObjectContext *)syncMOC
{
    self = [super init];
    if (self != nil) {
        self.syncMOC = syncMOC;
        self.hotFixDirectory = hotFixDirectory ?: [[ZMHotFixDirectory alloc] init];
    }
    return self;
}

- (void)applyPatches
{
    if ([[self.syncMOC persistentStoreMetadataForKey:ZMSkipHotfix] boolValue]) {
        ZMLogDebug(@"Skipping applying HotFix");
        return;
    }
    
    NSString * currentVersionString = [[[NSBundle bundleForClass:ZMUserSession.class] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    [self applyPatchesForCurrentVersion:currentVersionString];
}

- (void)applyPatchesForCurrentVersion:(NSString *)currentVersionString;
{
    if (currentVersionString.length == 0) {
        ZMLogDebug(@"Invalid version string, skipping HotFix");
        return;
    }

    ZMVersion *lastSavedVersion = [self lastSavedVersion];
    ZMVersion *currentVersion = [[ZMVersion alloc] initWithVersionString:currentVersionString];
    
    if (lastSavedVersion == nil) {
        ZMLogDebug(@"No saved last version. We assume it's a new database and don't apply any HotFix.");
        [self.syncMOC performGroupedBlock:^{
            [self saveNewVersion:currentVersionString];
            [self.syncMOC saveOrRollback];
        }];
        return;
    }
    
    if ([currentVersion compareWithVersion:lastSavedVersion] == NSOrderedSame) {
        ZMLogDebug(@"Current version equal to last saved version (%@). Not applying any HotFix.", lastSavedVersion.versionString);
        return;
    }
    
    ZMLogDebug(@"Applying HotFix with last saved version %@, current version %@.", lastSavedVersion.versionString, currentVersion.versionString);
    [self.syncMOC performGroupedBlock:^{
        [self applyFixesSinceVersion:lastSavedVersion];
        [self saveNewVersion:currentVersionString];
        [self.syncMOC saveOrRollback];
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
    }];
}

- (ZMVersion *)lastSavedVersion
{
    NSString *versionString = [self.syncMOC persistentStoreMetadataForKey:LastSavedVersionKey];
    if (nil == versionString) {
        return nil;
    }
    return [[ZMVersion alloc] initWithVersionString:versionString];
}

- (void)saveNewVersion:(NSString *)version
{
    [self.syncMOC setPersistentStoreMetadata:version forKey:LastSavedVersionKey];
    ZMLogDebug(@"Saved new HotFix version %@", version);
}

- (void)applyFixesSinceVersion:(ZMVersion *)lastSavedVersion
{
    for(ZMHotFixPatch *patch in self.hotFixDirectory.patches) {
        ZMVersion *version = [[ZMVersion alloc] initWithVersionString:patch.version];
        if ((lastSavedVersion == nil || [version compareWithVersion:lastSavedVersion] == NSOrderedDescending)
            && patch.code)
        {
            patch.code(self.syncMOC);
        }
    }
}

@end
