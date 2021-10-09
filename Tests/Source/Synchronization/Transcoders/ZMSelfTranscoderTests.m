// 


@import WireImages;
@import WireTransport;
@import WireSyncEngine;
@import WireDataModel;

#import "ObjectTranscoderTests.h"
#import "ZMSelfStrategy+Internal.h"
#import "ZMUserSession+Internal.h"
#import "WireSyncEngine_iOS_Tests-Swift.h"

@interface ZMSelfStrategyTests : ObjectTranscoderTests

@property (nonatomic) ZMSelfStrategy<ZMSingleRequestTranscoder> *sut;
@property (nonatomic) ZMUpstreamModifiedObjectSync *upstreamObjectSync;
@property (nonatomic) id mockClientRegistrationStatus;
@property (nonatomic) id requestSync;
@property (nonatomic) id syncStatus;

@property (nonatomic) ZMClientRegistrationStatus *realClientRegistrationStatus;
@property (nonatomic) NSTimeInterval originalRequestInterval;
@end



@implementation ZMSelfStrategyTests

- (void)setUp
{
    [super setUp];
    self.originalRequestInterval = ZMSelfStrategyPendingValidationRequestInterval;
    
    self.requestSync = [OCMockObject mockForClass:ZMSingleRequestSync.class];
    self.mockClientRegistrationStatus = [OCMockObject niceMockForClass:[ZMClientRegistrationStatus class]];
    self.syncStatus = [OCMockObject niceMockForClass:[SyncStatus class]];
    
    self.mockApplicationStatus.mockSynchronizationState = ZMSynchronizationStateEventProcessing;
    self.upstreamObjectSync = [OCMockObject niceMockForClass:ZMUpstreamModifiedObjectSync.class];
    [self.syncMOC performBlockAndWait:^{
        [ZMUser selfUserInContext:self.syncMOC].needsToBeUpdatedFromBackend = NO;
        [self.syncMOC saveOrRollback];
    }];
    self.sut = (id) [[ZMSelfStrategy alloc] initWithManagedObjectContext:self.syncMOC
                                                       applicationStatus:self.mockApplicationStatus
                                                clientRegistrationStatus:self.mockClientRegistrationStatus
                                                              syncStatus:self.syncStatus
                                                            upstreamObjectSync:self.upstreamObjectSync];
    
    WaitForAllGroupsToBeEmpty(0.5);
}

- (void)tearDown
{
    self.syncStatus = nil;
    self.requestSync = nil;
    [self.mockClientRegistrationStatus stopMocking];
    self.mockClientRegistrationStatus = nil;
    
    ZMSelfStrategyPendingValidationRequestInterval = self.originalRequestInterval;
    
    [self.realClientRegistrationStatus tearDown];
    self.realClientRegistrationStatus = nil;
    [(id)self.upstreamObjectSync stopMocking];
    self.upstreamObjectSync = nil;
    [self.sut tearDown];
    self.sut = nil;
    [super tearDown];
}

- (NSMutableDictionary *)samplePayloadForUserID:(NSUUID *)userID
{
    return [@{
              @"name" : @"Papineau",
              @"id" : userID.transportString,
              @"email" : @"pp@example.com",
              @"phone" : @"555-986-45789",
              @"accent_id" : @3,
              @"picture" : @[],
              } mutableCopy];
}

- (void)simulateNeedsSlowSync
{
    [(ZMClientRegistrationStatus* )[[self.mockClientRegistrationStatus stub] andReturnValue:@(ZMClientRegistrationPhaseWaitingForSelfUser)] currentPhase];
    [self.syncMOC performBlockAndWait:^{
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        selfUser.remoteIdentifier = nil;
        [self.syncMOC saveOrRollback];
    }];
}

- (void)testThatItRequestSelfUserIfNeedsSlowSync
{
    // given
    [self simulateNeedsSlowSync];
    
    // when
    ZMTransportRequest *request = [self.sut nextRequest];
    
    // then
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(@"/self", request.path);
    XCTAssertEqual(ZMMethodGET, request.method);
}

- (void)testThatItDoesNotRequestSelfUserIfSlowSyncIsDone
{
    // given
    [(ZMClientRegistrationStatus* )[[self.mockClientRegistrationStatus expect] andReturnValue:@(ZMClientRegistrationPhaseWaitingForSelfUser)] currentPhase];
    [self.syncMOC performBlockAndWait:^{
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        selfUser.remoteIdentifier = nil;
        [self.syncMOC saveOrRollback];
    }];
    
    NSDictionary *payload = [self samplePayloadForUserID:[NSUUID createUUID]];
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
    
    // simulate hard sync done
    ZMTransportRequest *request = [self.sut nextRequest];
    [request completeWithResponse:response];
    WaitForAllGroupsToBeEmpty(0.5);
    [(ZMClientRegistrationStatus* )[[self.mockClientRegistrationStatus expect] andReturnValue:@(ZMClientRegistrationPhaseRegistered)] currentPhase];
    
    // when
    request = [self.sut nextRequest];
    
    // then
    XCTAssertNil(request);
}

- (void)testThatItUpdatesSelfUser
{
    // given
    NSDictionary *payload = [self samplePayloadForUserID:[NSUUID createUUID]];
    [self simulateNeedsSlowSync];

    __block ZMUser *selfUser;
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
        ZMTransportRequest *request = [self.sut nextRequest];
        selfUser = [ZMUser selfUserInContext:self.syncMOC];
        
        // when
        [request completeWithResponse:response];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.syncMOC performGroupedBlockAndWait:^{
        // then
        XCTAssertEqualObjects(payload[@"id"], [selfUser.remoteIdentifier transportString]);
        XCTAssertEqualObjects(payload[@"name"], selfUser.name);
        XCTAssertEqualObjects(payload[@"email"], selfUser.emailAddress);
    }];
}


- (void)testThatItDoesNotRequestSelfUserWhileARequestIsAlreadyInProgress
{
    // given
    //
    // The self user is inserted automatically by -[NSManagedObjectContext syncContext]
    //
    
    ZMTransportRequest *req = [self.sut nextRequest];
    NOT_USED(req);
    
    // when
    ZMTransportRequest *nextReq = [self.sut nextRequest];
    
    // then
    XCTAssertNil(nextReq);
}

- (void)testThatItRequestsTheSelfUserAgain
{
    // given
    [self simulateNeedsSlowSync];
    NSDictionary *payload = [self samplePayloadForUserID:[NSUUID createUUID]];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
    
    
    // simulate hard sync done
    ZMTransportRequest *request = [self.sut nextRequest];
    [request completeWithResponse:response];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    [self simulateNeedsSlowSync];
    request = [self.sut nextRequest];
    
    // then
    XCTAssertNotNil(request);
    XCTAssertEqualObjects(request.path, @"/self");
    XCTAssertEqual(request.method, ZMMethodGET);
    XCTAssertNil(request.payload);
}



- (void)testThatItIndicatesThatTheSelfUserIsIncomplete
{
    // given
    // we have an incomplete self user

    // when
    BOOL hasSelfUser = [self.sut isSelfUserComplete];

    // then
    XCTAssertFalse(hasSelfUser);
}

- (void)testThatItIndicatesThatTheSelfUserIsComplete
{
    // given
    [self simulateNeedsSlowSync];

    [self.syncMOC performGroupedBlockAndWait:^{
        NSDictionary *payload = [self samplePayloadForUserID:[NSUUID createUUID]];
        
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
        ZMTransportRequest *request = [self.sut nextRequest];
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        NOT_USED(selfUser);

        // when
        [request completeWithResponse:response];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    [self.syncMOC performGroupedBlockAndWait:^{
        // then
        XCTAssertTrue([self.sut isSelfUserComplete]);
    }];
}


- (void)testThatItRequestsTheSelfUserAfterSetNeedSlowSync
{
    // given
    [self simulateNeedsSlowSync];
    XCTAssertFalse(self.sut.isSelfUserComplete);
    ZMTransportRequest *request = [self.sut nextRequest];

    NSDictionary *payload = [self samplePayloadForUserID:[NSUUID createUUID]];
    
    // complete request and hard sync
    [request completeWithResponse:[ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil]];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertTrue(self.sut.isSelfUserComplete);
    
    // when
    [self simulateNeedsSlowSync];
    
    // then
    ZMTransportRequest *secondRequest = [self.sut nextRequest];
    XCTAssertNotNil(secondRequest);

}

- (void)testThatItReturnsSlowSyncDoneAfterCompletingRequest
{
    // given
    [self simulateNeedsSlowSync];
    XCTAssertFalse(self.sut.isSelfUserComplete);

    ZMTransportRequest *request = [self.sut nextRequest];
    NSDictionary *payload = [self samplePayloadForUserID:[NSUUID createUUID]];
    
    // when
    [request completeWithResponse:[ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil]];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertTrue(self.sut.isSelfUserComplete);
}

- (void)testThatItCalls_FetchRequestForTrackedObjects_OnUpStreamObjectSync
{
    // expect
    NSFetchRequest *request = [OCMockObject niceMockForClass:[NSFetchRequest class]];
    [(ZMUpstreamModifiedObjectSync *)[[(id)self.upstreamObjectSync expect] andReturn:request] fetchRequestForTrackedObjects];

    // when
    NSFetchRequest *fetchRequest = [self.sut fetchRequestForTrackedObjects];

    XCTAssertEqual(fetchRequest, request);
}

- (void)testThatItCalls_addTrackedObjects_OnUpStreamObjectSync
{
    // expect
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    NSSet *objects = [NSSet setWithObject:selfUser];
    [[(OCMockObject *)self.upstreamObjectSync expect] addTrackedObjects:objects];
    
    // when
    [self.sut addTrackedObjects:objects];
}


@end



@implementation ZMSelfStrategyTests (UpstreamSync)

- (void)testThatItGeneratesARequestForUpdatingAssetsInSelfUser
{
    NSString *previewKey = @"new-key-1";
    NSString *completeKey = @"new-key-2";
    NSDictionary* uploadPayload = @{
                                    @"assets" : @[
                                            @{@"size" : @"preview", @"type" : @"image", @"key" : previewKey },
                                            @{@"size" : @"complete", @"type" : @"image", @"key" : completeKey }
                                            ],
                                    };
    
    [self checkThatItGeneratesUpstreamUpdateRequestWithPayload:uploadPayload changedKeys:[NSSet setWithObjects:@"previewProfileAssetIdentifier", @"completeProfileAssetIdentifier", nil] userChangeBlock:^(ZMUser *user) {
        user.previewProfileAssetIdentifier = previewKey;
        user.completeProfileAssetIdentifier = completeKey;
    }];
}


- (void)testThatItGeneratesARequestForUpdatingChangedSelfUser
{
    NSString *name = @"My new name testThatItGeneratesARequestForUpdatingChangedSelfUser";
    ZMAccentColor accentColor = ZMAccentColorBrightYellow;
    NSDictionary* uploadPayload = @{
                                    @"name" : name,
                                    @"accent_id" : @(accentColor)
                                    };
    
    [self checkThatItGeneratesUpstreamUpdateRequestWithPayload:uploadPayload changedKeys:[NSSet setWithObjects:@"name", @"accentColorValue", nil] userChangeBlock:^(ZMUser *user) {
        user.name = name;
        user.accentColorValue = accentColor;
    }];
}

- (void)testThatItGeneratesARequestForUpdatingJustTheNameInChangedSelfUser
{
    NSString *name = @"My new name testThatItGeneratesARequestForUpdatingJustTheNameInChangedSelfUser";

    NSDictionary* uploadPayload = @{
                                    @"name" : name
                                    };
    
    [self checkThatItGeneratesUpstreamUpdateRequestWithPayload:uploadPayload changedKeys:[NSSet setWithObjects:@"name", nil] userChangeBlock:^(ZMUser *user) {
        user.name = name;
    }];
}


- (void)testThatItGeneratesARequestForUpdatingJustTheAccentColorInChangedSelfUser
{
    ZMAccentColor accentColor = ZMAccentColorBrightYellow;
    NSDictionary* uploadPayload = @{
                                    @"accent_id" : @(accentColor)
                                    };
    
    [self checkThatItGeneratesUpstreamUpdateRequestWithPayload:uploadPayload changedKeys:[NSSet setWithObjects:@"accentColorValue", nil] userChangeBlock:^(ZMUser *user) {
        user.accentColorValue = accentColor;
    }];
}

- (void)checkThatItGeneratesUpstreamUpdateRequestWithPayload:(NSDictionary *)expectedPayload changedKeys:(NSSet *)changedKeys userChangeBlock:(void (^)(ZMUser *))userChangeBlock
{
    
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        userChangeBlock(selfUser);
        
        // when
        NSSet *updatedKeys = changedKeys;
        ZMUpstreamRequest *request = [(id<ZMUpstreamTranscoder>) self.sut requestForUpdatingObject:selfUser forKeys:updatedKeys];
        
        // then
        XCTAssertNotNil(request);
        XCTAssertEqualObjects(request.transportRequest.path, @"/self");
        XCTAssertEqual(request.transportRequest.method, ZMMethodPUT);
        XCTAssertEqualObjects(request.transportRequest.payload, expectedPayload);
        XCTAssertEqualObjects(request.keys, updatedKeys);
        
    }];
    
}


- (void)testThatItAlwaysReturnsNilForRequestsForInsertedObjects
{
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        
        // when
        ZMUpstreamRequest *request = [(id<ZMUpstreamTranscoder>) self.sut requestForInsertingObject:selfUser forKeys:[NSSet setWithObject:@"name"]];
        
        // then
        XCTAssertNil(request);
    }];
}


- (void)testThatItAlwaysReturnsNoForUpdatingUpdatedObject
{
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        selfUser.name = @"Joe Random User";
        ZMUpstreamRequest *request = [(id<ZMUpstreamTranscoder>) self.sut requestForInsertingObject:selfUser forKeys:[NSSet setWithObject:@"name"]];
        
        // when
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:nil HTTPStatus:200 transportSessionError:nil];
        BOOL needsToUpdateMoreObjects = [(id<ZMUpstreamTranscoder>) self.sut updateUpdatedObject:selfUser requestUserInfo:request.userInfo response:response keysToParse:[NSSet set]];
        
        // then
        XCTAssertFalse(needsToUpdateMoreObjects);
    }];
}



- (void)DISABLED_becauseItTraps_testThatItDoesNotGenerateARequestForUpdatingChangedNonSelfUser
{
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        user.name = @"Joe Random User";
        user.accentColorValue = ZMAccentColorBrightYellow;
        user.remoteIdentifier = [NSUUID createUUID];
        
        // when
        ZMUpstreamRequest *request = [(id<ZMUpstreamTranscoder>) self.sut requestForUpdatingObject:user forKeys:[NSSet setWithObjects:@"name", @"accentColorValue", nil]];
        
        // then
        XCTAssertNil(request);
    }];
}

- (void)testThatItReturnsAnPUTRequestForSelf
{
    // given
    [(ZMClientRegistrationStatus* )[[self.mockClientRegistrationStatus stub] andReturnValue:@(ZMClientRegistrationPhaseRegistered)] currentPhase];
    
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"/self" method:ZMMethodPUT payload:@{}];
    [[[(OCMockObject *)self.upstreamObjectSync expect] andReturn:request] nextRequest];
    [[[(OCMockObject *)self.upstreamObjectSync expect] andReturn:nil] nextRequest];
    
    // when
    ZMTransportRequest *receivedRequest = [self.sut nextRequest];
    
    // then
    XCTAssertEqual(receivedRequest, request);
}


- (void)testThatContextChangeTrackersContainUpstreamObjectSync
{
    [(ZMClientRegistrationStatus* )[[self.mockClientRegistrationStatus stub] andReturnValue:@(ZMClientRegistrationPhaseRegistered)] currentPhase];
    
    // when
    NSArray *changeTrackers = self.sut.contextChangeTrackers;
    
    // then
    XCTAssertTrue([changeTrackers containsObject:self.upstreamObjectSync]);
    
}

@end

@implementation ZMSelfStrategyTests (ClientRegistrationStatus)

- (void)testThatItForwardSelfUserUpdatesToTheClientRegsitrationStatus_RemoteIdentifier
{
    // given
    [(ZMClientRegistrationStatus *)[[self.mockClientRegistrationStatus expect] andReturnValue:OCMOCK_VALUE(ZMClientRegistrationPhaseWaitingForSelfUser)] currentPhase];
    [[self.mockClientRegistrationStatus expect] didFetchSelfUser];
    
    // when
    NSDictionary *payload = @{@"id": [NSUUID UUID].transportString,
                              @"tracking_id": @"someID"};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
    [self.sut didReceiveResponse:response forSingleRequest:self.requestSync];
    
    // then
    [self.mockClientRegistrationStatus verify];

}

- (void)testThatItForwardSelfUserUpdatesToTheClientRegsitrationStatus_EmailAddress
{
    // given
    [(ZMClientRegistrationStatus *)[[self.mockClientRegistrationStatus expect] andReturnValue:OCMOCK_VALUE(ZMClientRegistrationPhaseWaitingForEmailVerfication)] currentPhase];
    [[self.mockClientRegistrationStatus expect] didFetchSelfUser];
    
    // when
    NSDictionary *payload = @{@"email": @"my@example.com",
                              @"tracking_id": @"someID"};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
    [self.sut didReceiveResponse:response forSingleRequest:self.requestSync];
    
    // then
    [self.mockClientRegistrationStatus verify];
}

- (void)testThatOnSuccessfullyUpdatingEmailAddressItResetsTheTimeInterval
{
    // given
    [(ZMClientRegistrationStatus *)[[self.mockClientRegistrationStatus stub] andReturnValue:OCMOCK_VALUE(ZMClientRegistrationPhaseWaitingForEmailVerfication)] currentPhase];
    [[self.mockClientRegistrationStatus stub] didFetchSelfUser];
    ZMSelfStrategyPendingValidationRequestInterval = 5;
    
    // when
    NSDictionary *payload = @{@"email": @"my@example.com",
                              @"tracking_id": @"someID"};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
    [self.sut didReceiveResponse:response forSingleRequest:self.sut.timedDownstreamSync];
    
    // then
    XCTAssertEqual(self.sut.timedDownstreamSync.timeInterval, 0);
}

- (void)testThatOnUnsuccessfullyUpdatingEmailAddressItDoesNotResetTheTimeInterval
{
    // given
    [(ZMClientRegistrationStatus *)[[self.mockClientRegistrationStatus stub] andReturnValue:OCMOCK_VALUE(ZMClientRegistrationPhaseWaitingForEmailVerfication)] currentPhase];
    [[self.mockClientRegistrationStatus stub] didFetchSelfUser];
    ZMSelfStrategyPendingValidationRequestInterval = 5;
    
    // when
    NSDictionary *payload = @{@"email": [NSNull null],
                              @"tracking_id": @"someID"};
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
    [self.sut didReceiveResponse:response forSingleRequest:self.sut.timedDownstreamSync];
    
    // then
    XCTAssertEqualWithAccuracy(self.sut.timedDownstreamSync.timeInterval, 5, 0.5);
}

@end
