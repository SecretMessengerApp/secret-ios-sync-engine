// 


@import WireUtilities;
@import WireDataModel;

#import "ZMUserSession+Authentication.h"
#import "ZMUserSession+Internal.h"
#import "NSError+ZMUserSessionInternal.h"
#import "ZMCredentials.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

static NSString *ZMLogTag ZM_UNUSED = @"Authentication";

@implementation ZMUserSession (Authentication)

- (void)setEmailCredentials:(ZMEmailCredentials *)emailCredentials
{
    self.clientRegistrationStatus.emailCredentials = emailCredentials;
}

- (void)checkIfLoggedInWithCallback:(void (^)(BOOL))callback
{
    if (callback) {
        [self.msgManagedObjectContext performGroupedBlock:^{
            BOOL result = [self isLoggedIn];
            [self.managedObjectContext performGroupedBlock:^{
                callback(result);
            }];
        }];
    }
}

- (BOOL)needsToRegisterClient
{
    return true;
}

- (void)deleteUserKeychainItems;
{
    [self.transportSession.cookieStorage deleteKeychainItems];
}

- (void)closeAndDeleteCookie:(BOOL)deleteCookie
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSUserDefaults sharedUserDefaults] synchronize];

    if (deleteCookie) {
        [self deleteUserKeychainItems];
    }

    NSManagedObjectContext *refUIMoc = self.managedObjectContext;
    NSManagedObjectContext *refSyncMOC = self.syncManagedObjectContext;

    [refUIMoc performGroupedBlockAndWait:^{}];
    [refSyncMOC performGroupedBlockAndWait:^{}];

    [self tearDown];

    [refUIMoc performGroupedBlockAndWait:^{}];
    [refSyncMOC performGroupedBlockAndWait:^{}];

    refUIMoc = nil;
    refSyncMOC = nil;
}

@end
