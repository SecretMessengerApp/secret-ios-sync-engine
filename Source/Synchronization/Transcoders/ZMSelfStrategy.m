// 


@import WireImages;
@import WireSystem;
@import WireTransport;

#import "ZMSelfStrategy+Internal.h"
#import "ZMSyncStrategy.h"
#import "ZMUserSession+Internal.h"
#import "ZMClientRegistrationStatus.h"

static NSString *SelfPath = @"/self";

static NSString * const AccentColorValueKey = @"accentColorValue";
static NSString * const NameKey = @"name";
static NSString * const RemarkKey = @"reMark";
static NSString * const PreviewProfileAssetIdentifierKey = @"previewProfileAssetIdentifier";
static NSString * const CompleteProfileAssetIdentifierKey = @"completeProfileAssetIdentifier";

NSTimeInterval ZMSelfStrategyPendingValidationRequestInterval = 5;

@interface ZMSelfStrategy ()

@property (nonatomic) ZMUpstreamModifiedObjectSync *upstreamObjectSync;
@property (nonatomic) ZMSingleRequestSync *downstreamSelfUserSync;
@property (nonatomic) NSPredicate *needsToBeUdpatedFromBackend;
@property (nonatomic, weak) ZMClientRegistrationStatus *clientStatus;
@property (nonatomic, weak) SyncStatus *syncStatus;
@property (nonatomic) BOOL didCheckNeedsToBeUdpatedFromBackend;

@property (nonatomic) BOOL needFetchTributaryURL;
@end

@interface ZMSelfStrategy (SingleRequestTranscoder) <ZMSingleRequestTranscoder>
@end

@interface ZMSelfStrategy (UpstreamTranscoder) <ZMUpstreamTranscoder>
@end



@implementation ZMSelfStrategy

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)applicationStatus
                    clientRegistrationStatus:(ZMClientRegistrationStatus *)clientRegistrationStatus
                                  syncStatus:(SyncStatus *)syncStatus
{
    NSArray<NSString *> *keysToSync = @[NameKey, RemarkKey, AccentColorValueKey, PreviewProfileAssetIdentifierKey, CompleteProfileAssetIdentifierKey];
    
    ZMUpstreamModifiedObjectSync *upstreamObjectSync = [[ZMUpstreamModifiedObjectSync alloc]
                                                        initWithTranscoder:self
                                                        entityName:ZMUser.entityName
                                                        keysToSync:keysToSync
                                                        managedObjectContext:moc];
    
    return [self initWithManagedObjectContext:moc applicationStatus:applicationStatus clientRegistrationStatus:clientRegistrationStatus syncStatus: syncStatus upstreamObjectSync:upstreamObjectSync];
}

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)applicationStatus
                    clientRegistrationStatus:(ZMClientRegistrationStatus *)clientRegistrationStatus
                                  syncStatus:(SyncStatus *)syncStatus
                          upstreamObjectSync:(ZMUpstreamModifiedObjectSync *)upstreamObjectSync
{
    self = [super initWithManagedObjectContext:moc applicationStatus:applicationStatus];
    if(self) {
        self.clientStatus = clientRegistrationStatus;
        self.syncStatus = syncStatus;
        self.upstreamObjectSync = upstreamObjectSync;
        NSAssert(self.upstreamObjectSync != nil, @"upstreamObjectSync is nil");
        self.downstreamSelfUserSync = [[ZMSingleRequestSync alloc] initWithSingleRequestTranscoder:self groupQueue:self.managedObjectContext];
        self.needsToBeUdpatedFromBackend = [ZMUser predicateForNeedingToBeUpdatedFromBackend];
        _timedDownstreamSync = [[ZMTimedSingleRequestSync alloc] initWithSingleRequestTranscoder:self everyTimeInterval:ZMSelfStrategyPendingValidationRequestInterval groupQueue:self.managedObjectContext];
        [self checkIfNeedsToBeUdpatedFromBackend];
    }
    return self;
}

- (ZMStrategyConfigurationOption)configuration
{
    return ZMStrategyConfigurationOptionAllowsRequestsWhileUnauthenticated
         | ZMStrategyConfigurationOptionAllowsRequestsDuringSync
         | ZMStrategyConfigurationOptionAllowsRequestsDuringEventProcessing;
}

- (NSArray *)contextChangeTrackers
{
    return @[self.upstreamObjectSync, self];
}

- (void)tearDown
{
    [self.timedDownstreamSync invalidate];
    self.clientStatus = nil;
    self.syncStatus = nil;
}

- (SyncPhase)expectedSyncPhase
{
    return SyncPhaseFetchingSelfUser;
}

- (BOOL)isSyncing
{
    return self.syncStatus.currentSyncPhase == self.expectedSyncPhase;
}

- (ZMTransportRequest *)nextRequestIfAllowed;
{
    ZMClientRegistrationStatus *clientStatus = self.clientStatus;
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    
    if (!self.needFetchTributaryURL) {
        self.needFetchTributaryURL = YES;
        return [self requestForFetchTributaryURL];
    }
    
    if (clientStatus.currentPhase == ZMClientRegistrationPhaseWaitingForEmailVerfication) {
        [self.timedDownstreamSync readyForNextRequestIfNotBusy];
        return [self.timedDownstreamSync nextRequest];
    }
    if (clientStatus.currentPhase == ZMClientRegistrationPhaseWaitingForSelfUser || self.isSyncing) {
        if (! selfUser.needsToBeUpdatedFromBackend) {
            selfUser.needsToBeUpdatedFromBackend = YES;
            [self.managedObjectContext enqueueDelayedSave];
            [self.downstreamSelfUserSync readyForNextRequestIfNotBusy];
        }
        if (selfUser.needsToBeUpdatedFromBackend) {
            return [self.downstreamSelfUserSync nextRequest];
        }
    }
    else if (clientStatus.currentPhase == ZMClientRegistrationPhaseRegistered) {
        return [@[self.downstreamSelfUserSync, self.upstreamObjectSync] nextRequest];
    }
    return nil;
}


- (void)checkIfNeedsToBeUdpatedFromBackend;
{
    if (!self.didCheckNeedsToBeUdpatedFromBackend) {
        self.didCheckNeedsToBeUdpatedFromBackend = YES;
        ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
        if ([self.needsToBeUdpatedFromBackend evaluateWithObject:selfUser]) {
            [self.downstreamSelfUserSync readyForNextRequest];
        }
    }
}

- (BOOL)isSelfUserComplete
{
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    return selfUser.remoteIdentifier != nil;
}

- (ZMTransportRequest *)requestForFetchTributaryURL
{
    ZMTransportRequest *request = [ZMTransportRequest requestGetFromPath:@"/self/ipproxy"];
    [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.managedObjectContext block:^(ZMTransportResponse * response) {
        [self responseForFetchTributaryURLWith:response];
    }]];
    return request;
}

- (void)responseForFetchTributaryURLWith:(ZMTransportResponse*)response
{
    switch (response.result) {
        case ZMTransportResponseStatusSuccess: {
            NSString *url =
            [[[response.payload asDictionary] optionalDictionaryForKey:@"data"] optionalStringForKey:@"ip"];
            NSString *userId =
            [[[response.payload asDictionary] optionalDictionaryForKey:@"data"] optionalStringForKey:@"uid"];
            if (url && userId) {
                NSDictionary *tributaryURLs = [NSUserDefaults.standardUserDefaults objectForKey:@"tributaryURLs"];
                NSMutableDictionary * mutableDic = [[NSMutableDictionary alloc] initWithDictionary:tributaryURLs];
                if (![[tributaryURLs objectForKey:userId] isEqualToString:url]) {
                    NSLog(@"======%@", url);
                    [mutableDic setObject:url forKey:userId];
                    [NSUserDefaults.standardUserDefaults setObject:mutableDic forKey:@"tributaryURLs"];
                    [NSUserDefaults.standardUserDefaults synchronize];
                }
            }
            break;
        }
        default:
            break;
    }
}

@end



@implementation ZMSelfStrategy (UpstreamTranscoder)

- (BOOL)shouldProcessUpdatesBeforeInserts;
{
    return NO;
}

- (ZMUpstreamRequest *)requestForUpdatingObject:(ZMManagedObject *)managedObject forKeys:(NSSet *)keys;
{
    ZMUser *user = (ZMUser *)managedObject;
    if ([keys containsObject:RemarkKey]) {
        return [self requestForSettingRemarkOfUser:user changedKeys:keys];
    }
    Require(user.isSelfUser);

    if ([keys containsObject:AccentColorValueKey] ||
        [keys containsObject:NameKey] ||
        ([keys containsObject:PreviewProfileAssetIdentifierKey] && [keys containsObject:CompleteProfileAssetIdentifierKey])) {
        return [self requestForSettingBasicProfileDataOfUser:user changedKeys:keys];
    }
    ZMTrapUnableToGenerateRequest(keys, self);
    return nil;
}

- (ZMUpstreamRequest *)requestForSettingRemarkOfUser:(ZMUser *)user changedKeys:(NSSet *)keys
{
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"right"] = user.remoteIdentifier.transportString;
    payload[@"remark"] = user.reMark;
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"/users/setRemark" method:ZMMethodPOST payload:payload];
    
    return [[ZMUpstreamRequest alloc] initWithKeys:keys transportRequest:request];
}

- (ZMUpstreamRequest *)requestForSettingBasicProfileDataOfUser:(ZMUser *)user changedKeys:(NSSet *)keys
{
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    
    if([keys containsObject:NameKey]) {
        payload[@"name"] = user.name;
    }
    if([keys containsObject:AccentColorValueKey]) {
        payload[@"accent_id"] = @(user.accentColorValue);
    }
    if([keys containsObject:PreviewProfileAssetIdentifierKey] && [keys containsObject:CompleteProfileAssetIdentifierKey]) {
        payload[@"assets"] = [self profilePictureAssetsPayloadForUser:user];
    }
    
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:@"/self" method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:keys transportRequest:request];
}

- (NSArray *)profilePictureAssetsPayloadForUser:(ZMUser *)user {
    return @[
             @{
                 @"size" : @"preview",
                 @"key" : user.previewProfileAssetIdentifier,
                 @"type" : @"image"
                 },
             @{
                 @"size" : @"complete",
                 @"key" : user.completeProfileAssetIdentifier,
                 @"type" : @"image"
                 },
      ];
}

- (ZMUpstreamRequest *)requestForInsertingObject:(ZMManagedObject *)managedObject forKeys:(NSSet *)keys;
{
    NOT_USED(managedObject);
    NOT_USED(keys);
    return nil;
}

- (BOOL)updateUpdatedObject:(ZMUser *__unused )selfUser
            requestUserInfo:(NSDictionary *__unused )requestUserInfo
                   response:(ZMTransportResponse *__unused)response
                keysToParse:(NSSet *__unused )keysToParse
{
    return NO;
}
- (void)updateInsertedObject:(ZMManagedObject * __unused)managedObject request:(ZMUpstreamRequest *__unused)upstreamRequest response:(ZMTransportResponse *__unused)response;
{
    // we will never create a user on the backend with this sync
}

- (ZMManagedObject *)objectToRefetchForFailedUpdateOfObject:(ZMManagedObject *__unused)managedObject;
{
    return nil;
}

@end



@implementation ZMSelfStrategy (SingleRequestTranscoder)


- (ZMTransportRequest *)requestForSingleRequestSync:(ZMSingleRequestSync *)sync;
{
    NOT_USED(sync);
    return [ZMTransportRequest requestGetFromPath:SelfPath];
}

- (void)didReceiveResponse:(ZMTransportResponse *)response forSingleRequest:(ZMSingleRequestSync *)sync;
{
    NOT_USED(sync);
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    SyncStatus *syncStatus = self.syncStatus;
    
    if (response.result == ZMTransportResponseStatusSuccess) {
        
        ZMClientRegistrationStatus *clientStatus = self.clientStatus;
        ZMClientRegistrationPhase clientPhase = clientStatus.currentPhase;
        
        NSDictionary *payload = [response.payload asDictionary];
        [selfUser updateWithTransportData:payload authoritative:YES];
        
        // TODO: Write tests for all cases
        BOOL selfUserHasEmail = (selfUser.emailAddress != nil);
        BOOL needToNotifyAuthState = (clientPhase == ZMClientRegistrationPhaseWaitingForSelfUser) ||
                                     (clientPhase == ZMClientRegistrationPhaseWaitingForEmailVerfication);

        if (needToNotifyAuthState) {
            [clientStatus didFetchSelfUser];
        }
        
        if (sync == self.timedDownstreamSync) {
            if(!selfUserHasEmail) {
                if(self.timedDownstreamSync.timeInterval != ZMSelfStrategyPendingValidationRequestInterval) {
                    self.timedDownstreamSync.timeInterval = ZMSelfStrategyPendingValidationRequestInterval;
                }
            }
            else {
                self.timedDownstreamSync.timeInterval = 0;
            }
        }
        
        // Save to ensure self user is update to date when sync finishes
        [self.managedObjectContext saveOrRollback];
        
        if (self.isSyncing) {
            [syncStatus finishCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
        }
    } else if (response.result == ZMTransportResponseStatusPermanentError && self.isSyncing) {
        [syncStatus failCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
}

@end



@implementation ZMSelfStrategy (ContextChangeTracker)

- (NSFetchRequest *)fetchRequestForTrackedObjects
{
    [self checkIfNeedsToBeUdpatedFromBackend];
    return [self.upstreamObjectSync fetchRequestForTrackedObjects];
}

- (void)addTrackedObjects:(NSSet *)objects;
{
    [self.upstreamObjectSync addTrackedObjects:objects];
}

- (void)objectsDidChange:(NSSet *)objects
{
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    if ([objects containsObject:selfUser] && selfUser.needsToBeUpdatedFromBackend) {
        [self.downstreamSelfUserSync readyForNextRequest];
    }
}

@end
