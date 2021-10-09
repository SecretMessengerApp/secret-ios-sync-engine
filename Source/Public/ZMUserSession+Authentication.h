// 


@import Foundation;
@import WireSystem;

#import <WireSyncEngine/ZMUserSession.h>

@class ZMCredentials;

@interface ZMUserSession (Authentication)

- (void)setEmailCredentials:(ZMEmailCredentials *)emailCredentials;

/// Check whether the user is logged in
- (void)checkIfLoggedInWithCallback:(void(^)(BOOL loggedIn))callback;

/// This will delete user data stored by WireSyncEngine in the keychain.
- (void)deleteUserKeychainItems;

/// Delete cookies etc. and logout the current user.
- (void)closeAndDeleteCookie:(BOOL)deleteCookie;

@end


