// 


@import Foundation;
@import CoreData;
@import WireSystem;
@import WireDataModel;
@import WireRequestStrategy;

#import "ZMUserSession+Internal.h"
#import "ZMUserSession+Registration.h"
#import "ZMUserSession+Authentication.h"
#import "ZMOperationLoop+Private.h"
#import "ZMSyncStrategy.h"
#import "NSError+ZMUserSessionInternal.h"
#import "ZMUserSessionRegistrationNotification.h"
#import "ZMCredentials.h"
#import "ZMUserSessionRegistrationNotification.h"
#import "ZMAuthenticationStatus_Internal.h"

@implementation ZMUserSession (Registration)

- (BOOL)registeredOnThisDevice
{
    return [self.managedObjectContext registeredOnThisDevice];
}

@end
