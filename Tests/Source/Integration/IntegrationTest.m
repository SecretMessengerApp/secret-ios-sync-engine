//

#import <XCTest/XCTest.h>

@import avs;
@import UIKit;

#import "IntegrationTest.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"
#import <WireSyncEngine/WireSyncEngine.h>

@implementation IntegrationTest

- (void)setUp {
    [super setUp];
    BackgroundActivityFactory.sharedFactory.activityManager = UIApplication.sharedApplication;
    [BackgroundActivityFactory.sharedFactory resume];

    self.mockMediaManager = [[MockMediaManager alloc] init];
    self.mockEnvironment = [[MockEnvironment alloc] init];
 
    self.currentUserIdentifier = [NSUUID createUUID];
    [self _setUp];
}

- (void)tearDown {
    [self _tearDown];
    BackgroundActivityFactory.sharedFactory.activityManager = nil;
    
    self.mockMediaManager = nil;
    self.currentUserIdentifier = nil;
    self.mockEnvironment = nil;
    
    WaitForAllGroupsToBeEmpty(0.5);
    [NSFileManager.defaultManager removeItemAtURL:[MockUserClient mockEncryptionSessionDirectory] error:nil];
    
    [super tearDown];
}


- (SessionManagerConfiguration *)sessionManagerConfiguration {
    return [SessionManagerConfiguration defaultConfiguration];
}

- (BOOL)useInMemoryStore
{
    return YES;
}

- (BOOL)useRealKeychain
{
    return NO;
}

- (ZMTransportSession *)transportSession
{
    return (ZMTransportSession *)self.mockTransportSession;
}

@end
