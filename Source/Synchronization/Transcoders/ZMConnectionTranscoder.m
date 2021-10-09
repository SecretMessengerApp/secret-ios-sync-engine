// 


@import WireTransport;
@import WireDataModel;
@import WireRequestStrategy;

#import "ZMConnectionTranscoder+Internal.h"
#import "ZMSyncStrategy.h"
#import "ZMOperationLoop.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

static NSString *const PathConnections = @"/connections";

NSUInteger ZMConnectionTranscoderPageSize = 90;

@interface ZMConnectionTranscoder ()

@property (nonatomic) ZMUpstreamModifiedObjectSync *modifiedObjectSync;
@property (nonatomic) ZMUpstreamInsertedObjectSync *insertedObjectSync;
@property (nonatomic) ZMDownstreamObjectSync *downstreamSync;
@property (nonatomic) ZMSimpleListRequestPaginator *conversationsListSync;

@property (nonatomic, weak) SyncStatus *syncStatus;
@property (nonatomic, weak) id<ClientRegistrationDelegate> clientRegistrationDelegate;

@end


@interface ZMConnectionTranscoder (Pagination) <ZMSimpleListRequestPaginatorSync>

@end



@implementation ZMConnectionTranscoder

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc applicationStatus:(id<ZMApplicationStatus>)applicationStatus syncStatus:(SyncStatus *)syncStatus;
{
    self = [super initWithManagedObjectContext:moc applicationStatus:applicationStatus];
    if(self) {
        self.syncStatus = syncStatus;
        self.modifiedObjectSync = [[ZMUpstreamModifiedObjectSync alloc] initWithTranscoder:self entityName:ZMConnection.entityName managedObjectContext:self.managedObjectContext];
        self.insertedObjectSync = [[ZMUpstreamInsertedObjectSync alloc] initWithTranscoder:self entityName:ZMConnection.entityName managedObjectContext:self.managedObjectContext];
        self.conversationsListSync = [[ZMSimpleListRequestPaginator alloc] initWithBasePath:PathConnections startKey:@"start" pageSize:ZMConnectionTranscoderPageSize  managedObjectContext:moc includeClientID:NO transcoder:self];
        self.downstreamSync = [[ZMDownstreamObjectSync alloc] initWithTranscoder:self entityName:ZMConnection.entityName managedObjectContext:self.managedObjectContext];
    }
    return self;
}

- (ZMStrategyConfigurationOption)configuration
{
    return ZMStrategyConfigurationOptionAllowsRequestsDuringSync
         | ZMStrategyConfigurationOptionAllowsRequestsDuringEventProcessing;
}


- (SyncPhase)expectedSyncPhase
{
    return SyncPhaseFetchingConnections;
}

- (BOOL)isSyncing
{
    return self.syncStatus.currentSyncPhase == self.expectedSyncPhase;
}

- (ZMTransportRequest *)nextRequestIfAllowed
{
    if (self.isSyncing && !self.conversationsListSync.hasMoreToFetch) {
        [self.conversationsListSync resetFetching];
    }
    
    return [self.requestGenerators nextRequest];
}


- (NSArray *)contextChangeTrackers
{
    return @[self.downstreamSync, self.insertedObjectSync, self.modifiedObjectSync];
}

- (NSArray *)requestGenerators;
{
    if (self.isSyncing) {
        return @[self.conversationsListSync, self.insertedObjectSync, self.modifiedObjectSync];
    } else {
        return @[self.conversationsListSync, self.downstreamSync, self.insertedObjectSync, self.modifiedObjectSync];
    }
}

- (void)processEvents:(NSArray<ZMUpdateEvent *> *)events
           liveEvents:(BOOL)liveEvents
       prefetchResult:(__unused ZMFetchRequestBatchResult *)prefetchResult;
{

    if(!liveEvents) {
        return;
    }
    NSArray *userConnectionEvents = [events filterWithBlock:^BOOL(ZMUpdateEvent *evt) {
        return evt.type == ZMUpdateEventTypeUserConnection;
    }];
    
    for(ZMUpdateEvent *event in userConnectionEvents) {
        
        NSDictionary *connectionData = [event.payload dictionaryForKey:@"connection"];
        if(connectionData == nil) {
            ZMLogError(@"Connection update event missing connection: %@", event.payload);
            return;
        }
        
        [ZMConnection connectionFromTransportData:connectionData managedObjectContext:self.managedObjectContext];
    }
}

@end



@implementation ZMConnectionTranscoder (UpstreamTranscoder)

- (BOOL)shouldProcessUpdatesBeforeInserts;
{
    return NO;
}

- (ZMCompletionHandler *)rejectedConnectionCompletionHandlerForConversation:(ZMConversation *)conversation
{
    ZM_WEAK(self);
    NSManagedObjectID *conversationID = conversation.objectID;
    
    return [ZMCompletionHandler handlerOnGroupQueue:conversation.managedObjectContext block:^(ZMTransportResponse *response) {
        ZM_STRONG(self);
        if (response.HTTPStatus == 403 && [[response payloadLabel] isEqualToString:@"connection-limit"])
        {
            if (conversationID != nil) {
                ZMConversation *syncConversation = [self.managedObjectContext objectRegisteredForID:conversationID];
                if (syncConversation != nil) {
                    [self.managedObjectContext deleteObject:syncConversation];
                    [self.managedObjectContext enqueueDelayedSave];
                }
            }
            
            [self.managedObjectContext.zm_userInterfaceContext performGroupedBlock:^{
                [ZMConnectionLimitNotification notifyInContext:self.managedObjectContext];
            }];
        }
    }];
}

- (ZMUpstreamRequest *)requestForUpdatingObject:(ZMConnection *)connection forKeys:(NSSet *)keys;
{
    RequireString([keys isEqualToSet:[NSSet setWithObject:@"status"]],
                  "Unexpected set of changed keys: %s",
                  [keys.allObjects componentsJoinedByString:@","].UTF8String
                  );
    NSString *path = [NSString pathWithComponents:@[PathConnections, connection.to.remoteIdentifier.transportString]];
    NSDictionary *payload = @{@"status": connection.statusAsString};
    
    ZMTransportRequest *request = [[ZMTransportRequest alloc] initWithPath:path method:ZMMethodPUT payload:payload];
    [request addCompletionHandler:[self rejectedConnectionCompletionHandlerForConversation:connection.conversation]];
 
    return [[ZMUpstreamRequest alloc] initWithKeys:keys transportRequest:request];
}

- (ZMUpstreamRequest *)requestForInsertingObject:(ZMConnection *)connection forKeys:(NSSet *)keys;
{
    NOT_USED(keys);
    RequireString(connection.to != nil, "Connection has no user.");
    RequireString(connection.to.remoteIdentifier != nil, "Connection's user has no remote ID.");
    VerifyString(connection.status, "Connection status is not 'sent' (%u).", (int) connection.status);
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"user"] = connection.to.remoteIdentifier.transportString;
    NSString *name = [ZMUser selfUserInContext:self.managedObjectContext].name;
    if (0 < name.length) {
        payload[@"name"] = [name copy];
    }
    if (connection.message) {
        payload[@"message"] = [connection.message copy];
    } 
    ZMTransportRequest *request = [[ZMTransportRequest alloc] initWithPath:PathConnections method:ZMMethodPOST payload:payload];
    [request addCompletionHandler:[self rejectedConnectionCompletionHandlerForConversation:connection.conversation]];
    
    return [[ZMUpstreamRequest alloc] initWithTransportRequest:request];
}

- (void)updateInsertedObject:(ZMConnection *)connection request:(ZMUpstreamRequest *__unused)upstreamRequest response:(ZMTransportResponse *)response;
{
    NSDictionary *payloadDictionary = response.payload.asDictionary;
    VerifyString([[payloadDictionary stringForKey:@"to"] isEqualToString:connection.to.remoteIdentifier.transportString], "'to' key in response does not match local connection.");
    
    connection.existsOnBackend = YES;
    // If it wasn't created by this request, we need to re-fetch it:
    const BOOL justCreated = upstreamRequest.transportResponse.HTTPStatus == 201;
    connection.needsToBeUpdatedFromBackend = ! justCreated;
    
    [ZMConnection connectionFromTransportData:payloadDictionary managedObjectContext:self.managedObjectContext];
}

- (BOOL)updateUpdatedObject:(ZMConnection *)connection
            requestUserInfo:(NSDictionary *)requestUserInfo
                   response:(ZMTransportResponse *)response
                keysToParse:(NSSet *)keysToParse
{
    NOT_USED(keysToParse);
    NOT_USED(requestUserInfo);
    [connection updateFromTransportData:response.payload.asDictionary];
    if (connection.hasValidConversation) {
        connection.conversation.needsToBeUpdatedFromBackend = YES;
    }
    return NO;
}

- (ZMManagedObject *)objectToRefetchForFailedUpdateOfObject:(ZMConnection *)connection;
{
    return connection;
}

@end



@implementation ZMConnectionTranscoder (DownstreamTranscoder)

- (ZMTransportRequest *)requestForFetchingObject:(ZMConnection *)connection downstreamSync:(id<ZMObjectSync>)downstreamSync
{
    NOT_USED(downstreamSync);
    if (connection.to.remoteIdentifier == nil || connection.needsToBeUpdatedFromBackend == NO) {
        return nil;
    }

    NSString *path = [NSString pathWithComponents:@[PathConnections, connection.to.remoteIdentifier.transportString]];
    ZMTransportRequest *request = [[ZMTransportRequest alloc] initWithPath:path method:ZMMethodGET payload:nil];
    return request;
    
}
- (void)updateObject:(ZMConnection *)connection withResponse:(ZMTransportResponse *)response downstreamSync:(id<ZMObjectSync>)downstreamSync
{
    NOT_USED(downstreamSync);
    connection.needsToBeUpdatedFromBackend = NO;
    
    NSDictionary *dictionaryPayload = [response.payload asDictionary];
    VerifyReturn(dictionaryPayload != nil);
    [connection updateFromTransportData:dictionaryPayload];
    [connection updateConversationType];
}

- (void)deleteObject:(ZMConnection *)connection withResponse:(ZMTransportResponse *)response downstreamSync:(id<ZMObjectSync>)downstreamSync
{
    if (response.isPermanentylUnavailableError) {
        connection.needsToBeUpdatedFromBackend = NO;
    }
    
    NOT_USED(downstreamSync);
}

@end



@implementation ZMConnectionTranscoder (Pagination)


- (NSUUID *)nextUUIDFromResponse:(ZMTransportResponse *)response forListPaginator:(ZMSimpleListRequestPaginator *)paginator
{
    NOT_USED(paginator);

    NSMutableArray *allUIDs = [NSMutableArray array];

    NSArray *connectionPayload = [[response.payload asDictionary] optionalArrayForKey:@"connections"];
    VerifyReturnNil(connectionPayload != nil);

    for (NSDictionary *rawConnection in connectionPayload) {
        ZMConnection *connection = [ZMConnection connectionFromTransportData:rawConnection managedObjectContext:self.managedObjectContext];
        if (connection != nil && connection.to != nil) {
            [allUIDs addObject:connection.to.remoteIdentifier];
        }
    }
    
    SyncStatus *syncStatus = self.syncStatus;
    
    if (!self.conversationsListSync.hasMoreToFetch && self.isSyncing) {
        [syncStatus finishCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
    
    return allUIDs.lastObject;
}

- (BOOL)shouldParseErrorForResponse:(ZMTransportResponse*)response
{
    SyncStatus *syncStatus = self.syncStatus;
    
    if (response.result == ZMTransportResponseStatusPermanentError && self.isSyncing) {
        [syncStatus failCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
    return NO;
}

@end

