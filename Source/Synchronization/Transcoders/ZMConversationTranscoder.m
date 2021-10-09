// 


@import WireSystem;
@import WireUtilities;
@import WireTransport;
@import WireDataModel;
@import WireRequestStrategy;

#import "ZMConversationTranscoder.h"
#import "ZMAuthenticationStatus.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

static NSString* ZMLogTag ZM_UNUSED = @"Conversations";

NSString *const ConversationsPath = @"/conversations";

NSString *const V3Assetspath = @"/assets/v3";

NSString *const ConversationServiceMessageAdd = @"ConversationServiceMessageAdd";
NSString *const ConversationOtrMessageAdd = @"ConversationOtrMessageAdd";
NSString *const ConversationUserConnection = @"ConversationUserConnection";
NSString *const ConversationApplyToTestNotification = @"ConversationApplyToTestNotification";

static NSString *const ConversationIDsPath = @"/conversations/ids";

NSUInteger ZMConversationTranscoderListPageSize = 100;
const NSUInteger ZMConversationTranscoderDefaultConversationPageSize = 32;

static NSString *const UserInfoTypeKey = @"type";
static NSString *const UserInfoUserKey = @"user";
static NSString *const UserInfoAddedValueKey = @"added";
static NSString *const UserInfoRemovedValueKey = @"removed";


static NSString *const ConversationTeamKey = @"team";
static NSString *const ConversationAccessKey = @"access";
static NSString *const ConversationAccessRoleKey = @"access_role";
static NSString *const ConversationTeamIdKey = @"teamid";
static NSString *const ConversationTeamManagedKey = @"managed";

@interface ZMConversationTranscoder () <ZMSimpleListRequestPaginatorSync>

@property (nonatomic) ZMUpstreamModifiedObjectSync *modifiedSync;
@property (nonatomic) ZMUpstreamInsertedObjectSync *insertedSync;

@property (nonatomic) ZMDownstreamObjectSync *downstreamSync;
@property (nonatomic) ZMRemoteIdentifierObjectSync *remoteIDSync;
@property (nonatomic) ZMSimpleListRequestPaginator *listPaginator;

@property (nonatomic, weak) SyncStatus *syncStatus;
@property (nonatomic, weak) id<PushMessageHandler> localNotificationDispatcher;
@property (nonatomic) NSMutableOrderedSet<ZMConversation *> *lastSyncedActiveConversations;

@end


@interface ZMConversationTranscoder (DownstreamTranscoder) <ZMDownstreamTranscoder>
@end


@interface ZMConversationTranscoder (UpstreamTranscoder) <ZMUpstreamTranscoder>
@end


@interface ZMConversationTranscoder (PaginatedRequest) <ZMRemoteIdentifierObjectTranscoder>
@end


@implementation ZMConversationTranscoder

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc applicationStatus:(id<ZMApplicationStatus>)applicationStatus;
{
    Require(NO);
    self = [super initWithManagedObjectContext:moc applicationStatus:applicationStatus];
    NOT_USED(self);
    self = nil;
    return self;
}

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                           applicationStatus:(id<ZMApplicationStatus>)applicationStatus
                 localNotificationDispatcher:(id<PushMessageHandler>)localNotificationDispatcher
                                  syncStatus:(SyncStatus *)syncStatus;
{
    self = [super initWithManagedObjectContext:managedObjectContext applicationStatus:applicationStatus];
    if (self) {
        self.localNotificationDispatcher = localNotificationDispatcher;
        self.syncStatus = syncStatus;
        self.lastSyncedActiveConversations = [[NSMutableOrderedSet alloc] init];
        self.modifiedSync = [[ZMUpstreamModifiedObjectSync alloc] initWithTranscoder:self entityName:ZMConversation.entityName updatePredicate:nil filter:nil keysToSync:self.keysToSync managedObjectContext:self.managedObjectContext];
        self.insertedSync = [[ZMUpstreamInsertedObjectSync alloc] initWithTranscoder:self
                                                                          entityName:ZMConversation.entityName
                                                                        filter:nil
                                                managedObjectContext:self.managedObjectContext];
        NSPredicate *conversationPredicate =
        [NSPredicate predicateWithFormat:@"%K != %@ AND (connection == nil OR (connection.status != %d AND connection.status != %d) ) AND needsToBeUpdatedFromBackend == YES",
         [ZMConversation remoteIdentifierDataKey], nil,
         ZMConnectionStatusPending,  ZMConnectionStatusIgnored
         ];
         
        self.downstreamSync = [[ZMDownstreamObjectSync alloc] initWithTranscoder:self entityName:ZMConversation.entityName predicateForObjectsToDownload:conversationPredicate managedObjectContext:self.managedObjectContext];
        self.listPaginator = [[ZMSimpleListRequestPaginator alloc] initWithBasePath:ConversationIDsPath
                                                                           startKey:@"start"
                                                                           pageSize:ZMConversationTranscoderListPageSize
                                                               managedObjectContext:self.managedObjectContext
                                                                    includeClientID:NO
                                                                         transcoder:self];
        self.conversationPageSize = ZMConversationTranscoderDefaultConversationPageSize;
        self.remoteIDSync = [[ZMRemoteIdentifierObjectSync alloc] initWithTranscoder:self managedObjectContext:self.managedObjectContext];
    }
    return self;
}

- (ZMStrategyConfigurationOption)configuration
{
    return ZMStrategyConfigurationOptionAllowsRequestsDuringSync
         | ZMStrategyConfigurationOptionAllowsRequestsDuringEventProcessing;
}


- (NSArray<NSString *> *)keysToSync
{
    NSArray *keysWithRef = @[
             ZMConversationArchivedChangedTimeStampKey,
             ZMConversationSilencedChangedTimeStampKey,
             ];
    NSArray *allKeys = [keysWithRef arrayByAddingObjectsFromArray:self.keysToSyncWithoutRef];
    return allKeys;
}

- (NSArray<NSString *>*)keysToSyncWithoutRef
{
    // Some keys don't have or are a time reference
    // These keys will always be over written when updating from the backend
    // They might be overwritten in a way that they don't create requests anymore whereas they previously did
    // To avoid crashes or unneccessary syncs, we should reset those when refetching the conversation from the backend

    return @[ZMConversationUserDefinedNameKey,
             ZMConversationAutoReplyKey,
             ZMConversationSelfRemarkKey,
             ZMConversationIsOpenCreatorInviteVerifyKey,
             ZMConversationIsOpenMemberInviteVerifyKey,
             ZMConversationOnlyCreatorInviteKey,
             ZMConversationOpenUrlJoinKey,
             ZMConversationAllowViewMembersKey,
             CreatorKey,
             ZMConversationIsVisibleForMemberChangeKey,
             ZMConversationIsAllowMemberAddEachOtherKey,
             ZMConversationIsDisableSendMsgKey,
             ZMConversationInfoOratorKey,
             ZMConversationManagerAddKey,
             ZMConversationManagerDelKey,
             ZMConversationIsPlacedTopKey,
             ZMConversationIsMessageVisibleOnlyManagerAndCreatorKey,
             ZMConversationAnnouncementKey,
             ZMConversationPreviewAvatarKey,
             ZMConversationCompleteAvatarKey,
             ShowMemsumKey,
             EnabledEditMsgKey,
//             EnabledEditPersonalMsgKey,
             ZMConversationInfoOpenScreenShotKey
             ];
}

- (NSUUID *)nextUUIDFromResponse:(ZMTransportResponse *)response forListPaginator:(ZMSimpleListRequestPaginator *)paginator
{
    NOT_USED(paginator);
    
    NSDictionary *payload = [response.payload asDictionary];
    NSArray *conversationIDStrings = [payload arrayForKey:@"conversations"];
    NSArray *conversationUUIDs = [conversationIDStrings mapWithBlock:^id(NSString *obj) {
        return [obj UUID];
    }];
    NSSet *conversationUUIDSet = [NSSet setWithArray:conversationUUIDs];
    [self.remoteIDSync addRemoteIdentifiersThatNeedDownload:conversationUUIDSet];
    
    
    if (response.result == ZMTransportResponseStatusPermanentError && self.isSyncing) {
        [self.syncStatus failCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
    
    [self finishSyncIfCompleted];
    
    return conversationUUIDs.lastObject;
}

- (void)finishSyncIfCompleted
{
    if (!self.listPaginator.hasMoreToFetch && self.remoteIDSync.isDone && self.isSyncing) {
        [self updateInactiveConversations:self.lastSyncedActiveConversations];
        [self.lastSyncedActiveConversations removeAllObjects];
        [self.syncStatus finishCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
}

- (void)updateInactiveConversations:(NSOrderedSet<ZMConversation *> *)activeConversations
{
    NSMutableOrderedSet *inactiveConversations = [NSMutableOrderedSet orderedSetWithArray:[self.managedObjectContext executeFetchRequestOrAssert:[ZMConversation sortedFetchRequest]]];
    [inactiveConversations minusOrderedSet:activeConversations];
    
    for (ZMConversation *inactiveConversation in inactiveConversations) {
        if (inactiveConversation.conversationType == ZMConversationTypeGroup) {
            inactiveConversation.needsToBeUpdatedFromBackend = YES;
        }
    }
}

- (SyncPhase)expectedSyncPhase
{
    return SyncPhaseFetchingConversations;
}

- (BOOL)isSyncing
{
    return self.syncStatus.currentSyncPhase == self.expectedSyncPhase;
}

- (ZMTransportRequest *)nextRequestIfAllowed
{
    if (self.isSyncing && self.listPaginator.status != ZMSingleRequestInProgress && self.remoteIDSync.isDone) {
        [self.listPaginator resetFetching];
        [self.remoteIDSync setRemoteIdentifiersAsNeedingDownload:[NSSet set]];
    }
    
    return [self.requestGenerators nextRequest];
}

- (NSArray *)contextChangeTrackers
{
    return @[self.downstreamSync, self.insertedSync, self.modifiedSync];
}

- (NSArray *)requestGenerators;
{
    if (self.isSyncing) {
        return  @[self.listPaginator, self.remoteIDSync];
    } else {
        return  @[self.downstreamSync, self.insertedSync, self.modifiedSync];
    }
}

- (ZMConversation *)createConversationFromTransportData:(NSDictionary *)transportData
                                        serverTimeStamp:(NSDate *)serverTimeStamp
                                                 source:(ZMConversationSource)source
{
    // If the conversation is not a group conversation, we need to make sure that we check if there's any existing conversation without a remote identifier for that user.
    // If it is a group conversation, we don't need to.
    
    NSNumber *typeNumber = [transportData numberForKey:@"type"];
    VerifyReturnNil(typeNumber != nil);
    ZMConversationType const type = [ZMConversation conversationTypeFromTransportData:typeNumber];

    if (type == ZMConversationTypeGroup  ||
        type == ZMConversationTypeHugeGroup ||
        type == ZMConversationTypeSelf) {
        return [self createGroupOrSelfConversationFromTransportData:transportData serverTimeStamp:serverTimeStamp source: source];
    } else {
        return [self createOneOnOneConversationFromTransportData:transportData type:type serverTimeStamp:serverTimeStamp];
    }
}

- (ZMConversation *)createOneOnOneConversationFromTransportData:(NSDictionary *)transportData
                                                           type:(ZMConversationType const)type
                                                serverTimeStamp:(NSDate *)serverTimeStamp;
{
    NSUUID * const convRemoteID = [transportData uuidForKey:@"id"];
    if(convRemoteID == nil) {
        ZMLogError(@"Missing ID in conversation payload");
        return nil;
    }
    
    // Get the 'other' user:
    NSDictionary *members = [transportData dictionaryForKey:@"members"];
    
    NSArray *others = [members arrayForKey:@"others"];

    if ((type == ZMConversationTypeConnection) && (others.count == 0)) {
        // But be sure to update the conversation if it already exists:
        ZMConversation *conversation = [ZMConversation conversationWithRemoteID:convRemoteID createIfNeeded:NO inContext:self.managedObjectContext];
        if ((conversation.conversationType != ZMConversationTypeOneOnOne) &&
            (conversation.conversationType != ZMConversationTypeConnection))
        {
            conversation.conversationType = type;
        }
        
        // Ignore everything else since we can't find out which connection it belongs to.
        return conversation;
    }
    
    VerifyReturnNil(others.count != 0); // No other users? Self conversation?
    VerifyReturnNil(others.count < 2); // More than 1 other user in a conversation that's not a group conversation?
    
    NSUUID *otherUserRemoteID = [[others[0] asDictionary] uuidForKey:@"id"];
    VerifyReturnNil(otherUserRemoteID != nil); // No remote ID for other user?
    
    ZMUser *user = [ZMUser userWithRemoteID:otherUserRemoteID createIfNeeded:YES inContext:self.managedObjectContext];
    ZMConversation *conversation = user.connection.conversation;
    
    BOOL conversationCreated = NO;
    if (conversation == nil) {
        // if the conversation already exist, it will pick it up here and hook it up to the connection
        conversation = [ZMConversation conversationWithRemoteID:convRemoteID createIfNeeded:YES inContext:self.managedObjectContext created:&conversationCreated];
        RequireString(conversation.conversationType != ZMConversationTypeGroup && conversation.conversationType != ZMConversationTypeHugeGroup,
                      "Conversation for connection is a group conversation: %s",
                      convRemoteID.transportString.UTF8String);
        user.connection.conversation = conversation;
    } else {
        // check if a conversation already exists with that ID
        [conversation mergeWithExistingConversationWithRemoteID:convRemoteID];
        conversationCreated = YES;
    }
    
    conversation.remoteIdentifier = convRemoteID;
    [conversation updateWithTransportData:transportData serverTimeStamp:serverTimeStamp];
    return conversation;
}


- (BOOL)shouldProcessUpdateEvent:(ZMUpdateEvent *)event
{
    switch (event.type) {
        case ZMUpdateEventTypeConversationMessageAdd:
        case ZMUpdateEventTypeConversationClientMessageAdd:
        case ZMUpdateEventTypeConversationOtrMessageAdd:
        case ZMUpdateEventTypeConversationOtrAssetAdd:
        case ZMUpdateEventTypeConversationKnock:
        case ZMUpdateEventTypeConversationAssetAdd:
        case ZMUpdateEventTypeConversationMemberJoin:
        case ZMUpdateEventTypeConversationMemberLeave:
        case ZMUpdateEventTypeConversationRename:
        case ZMUpdateEventTypeConversationMemberUpdate:
        case ZMUpdateEventTypeConversationCreate:
        case ZMUpdateEventTypeConversationDelete:
        case ZMUpdateEventTypeConversationConnectRequest:
        case ZMUpdateEventTypeConversationAccessModeUpdate:
        case ZMUpdateEventTypeConversationMessageTimerUpdate:
        case ZMUpdateEventTypeConversationUpdateAutoreply:
        case ZMUpdateEventTypeConversationChangeType:
        case ZMUpdateEventTypeConversationChangeCreater:
        case ZMUpdateEventTypeConversationUpdateAliasname:
        case ZMUpdateEventTypeConversationBgpMessageAdd:
        case ZMUpdateEventTypeConversationServiceMessageAdd:
        case ZMUpdateEventTypeConversationUpdate:
        case ZMUpdateEventTypeConversationUpdateBlockTime:
        case ZMUpdateEventTypeConversationAppMessageAdd:
        case ZMUpdateEventTypeConversationReceiptModeUpdate:
        case ZMUpdateEventTypeConversationJsonMessageAdd:
            return YES;
        default:
            return NO;
    }
}

- (ZMConversation *)conversationFromEventPayload:(ZMUpdateEvent *)event conversationMap:(ZMConversationMapping *)prefetchedMapping
{
    NSUUID * const conversationID = [event.payload optionalUuidForKey:@"conversation"];
    
    if (nil == conversationID) {
        return nil;
    }
    
    if (nil != prefetchedMapping[conversationID]) {
        return prefetchedMapping[conversationID];
    }
    
    ZMConversation *conversation = [ZMConversation conversationWithRemoteID:conversationID createIfNeeded:NO inContext:self.managedObjectContext];
    if (conversation == nil) {
        conversation = [ZMConversation conversationWithRemoteID:conversationID createIfNeeded:YES inContext:self.managedObjectContext];
        // if we did not have this conversation before, refetch it
        conversation.needsToBeUpdatedFromBackend = YES;
    }
    return conversation;
}

- (BOOL)isSelfConversationEvent:(ZMUpdateEvent *)event;
{
    NSUUID * const conversationID = event.conversationUUID;
    return [conversationID isSelfConversationRemoteIdentifierInContext:self.managedObjectContext];
}

- (void)createConversationFromEvent:(ZMUpdateEvent *)event {
    NSDictionary *payloadData = [event.payload dictionaryForKey:@"data"];
    if(payloadData == nil) {
        ZMLogError(@"Missing conversation payload in ZMUpdateEventConversationCreate");
        return;
    }
    NSDate *serverTimestamp = [event.payload dateFor:@"time"];
    [self createConversationFromTransportData:payloadData serverTimeStamp:serverTimestamp source:ZMConversationSourceUpdateEvent];
}

- (ZMConversation *)createConversationAndJoinMemberFromEvent:(ZMUpdateEvent *)event {
    NSDictionary *payloadData = event.payload;
    if(payloadData == nil) {
        ZMLogError(@"Missing conversation payload in ZMUpdateEventTypeConversationServiceMessageAdd");
        return nil;
    }
    NSDate *serverTimestamp = [event.payload dateFor:@"time"];
    NSUUID * const convRemoteID = [payloadData uuidForKey:@"conversation"];
    if(convRemoteID == nil) {
        ZMLogError(@"Missing ID in conversation payload");
        return nil;
    }
    NSUUID * const userId = [payloadData uuidForKey:@"from"];

    ZMConversation *conversation = [ZMConversation conversationWithRemoteID:convRemoteID
                                                             createIfNeeded:YES
                                                                  inContext:self.managedObjectContext];
    
    ZMConnection *connection = [ZMConnection connectionWithUserUUID:userId
                                                          inContext:self.managedObjectContext];
    
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.connection = connection;
    [conversation updateLastModified:serverTimestamp];
    [conversation updateServerModified:serverTimestamp];
    conversation.isServiceNotice = YES;
    return conversation;
}


- (void)deleteConversationFromEvent:(ZMUpdateEvent *)event
{
    NSUUID *conversationId = event.conversationUUID;
    
    if (conversationId == nil) {
        ZMLogError(@"Missing conversation payload in ZMupdateEventConversatinDelete");
        return;
    }
    
    ZMConversation *conversation = [ZMConversation conversationWithRemoteID:conversationId createIfNeeded:NO inContext:self.managedObjectContext];
    
    if (conversation != nil) {
        [self.managedObjectContext deleteObject:conversation];
    }
}

- (void)processEvents:(NSArray<ZMUpdateEvent *> *)events
           liveEvents:(BOOL)liveEvents
       prefetchResult:(ZMFetchRequestBatchResult *)prefetchResult;
{
    for (ZMUpdateEvent *event in events) {

        if (event.type == ZMUpdateEventTypeConversationServiceMessageAdd) {
            [self createConversationAndJoinMemberFromEvent:event];
            continue;
        }
        
        if (event.type == ZMUpdateEventTypeConversationCreate) {
            [self createConversationFromEvent:event];
            continue;
        }
        
        if (event.type == ZMUpdateEventTypeConversationDelete) {
            [self deleteConversationFromEvent:event];
            continue;
        }
        
        if ([self isSelfConversationEvent:event]) {
            continue;
        }
        
        if (![self shouldProcessUpdateEvent:event]) {
            continue;
        }
        
        ZMConversation *conversation = [self conversationFromEventPayload:event
                                                          conversationMap:prefetchResult.conversationsByRemoteIdentifier];
        if (conversation == nil) {
            continue;
        }
        [self markConversationForDownloadIfNeeded:conversation afterEvent:event];
        
        
        NSDate * const currentLastTimestamp = conversation.lastServerTimeStamp;
        [conversation updateWithUpdateEvent:event];
        
        if (liveEvents) {
            [self processUpdateEvent:event forConversation:conversation previousLastServerTimestamp:currentLastTimestamp];
        }
    }
}

- (NSSet<NSUUID *> *)conversationRemoteIdentifiersToPrefetchToProcessEvents:(NSArray<ZMUpdateEvent *> *)events
{
    return [NSSet setWithArray:[events mapWithBlock:^NSUUID *(ZMUpdateEvent *event) {
        return [event.payload optionalUuidForKey:@"conversation"];
    }]];
}


- (void)markConversationForDownloadIfNeeded:(ZMConversation *)conversation afterEvent:(ZMUpdateEvent *)event {
    
    if (conversation.conversationType == ZMConversationTypeHugeGroup) {
        return;
    }
    
    if (event.type == ZMUpdateEventTypeConversationMemberLeave) {
        NSDictionary *data = [event.payload dictionaryForKey:@"data"];
        NSArray *leavingUserIds = [data optionalArrayForKey:@"user_ids"];
        ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
        if ([leavingUserIds containsObject:selfUser.remoteIdentifier.transportString]) {
            return;
        }
    }
    
    switch(event.type) {
        case ZMUpdateEventTypeConversationOtrAssetAdd:
        case ZMUpdateEventTypeConversationOtrMessageAdd:
        case ZMUpdateEventTypeConversationRename:
        case ZMUpdateEventTypeConversationMemberLeave:
        case ZMUpdateEventTypeConversationKnock:
        case ZMUpdateEventTypeConversationMessageAdd:
        case ZMUpdateEventTypeConversationTyping:
        case ZMUpdateEventTypeConversationAssetAdd:
        case ZMUpdateEventTypeConversationClientMessageAdd:
            break;
        default:
            return;
    }
    
    BOOL isConnection = conversation.connection.status == ZMConnectionStatusPending
        || conversation.connection.status == ZMConnectionStatusSent
        || conversation.conversationType == ZMConversationTypeConnection; // the last OR should be covered by the
                                                                      // previous cases already, but just in case..
    if (isConnection || conversation.conversationType == ZMConversationTypeInvalid) {
        conversation.needsToBeUpdatedFromBackend = YES;
        conversation.connection.needsToBeUpdatedFromBackend = YES;
    }
}

- (void)processUpdateEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation previousLastServerTimestamp:(NSDate *)previousLastServerTimestamp
{
    switch (event.type) {
        case ZMUpdateEventTypeConversationRename:
            [self processConversationRenameEvent:event forConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationMemberJoin:
            if (conversation.conversationType == ZMConversationTypeHugeGroup) {
                [self processMemberJoinEvent:event forHugeConversation:conversation];
            } else {
                [self processMemberJoinEvent:event forConversation:conversation];
            }
            break;
        case ZMUpdateEventTypeConversationMemberLeave:
            if (conversation.conversationType == ZMConversationTypeHugeGroup) {
                [self processMemberLeaveEvent:event forHugeConversation:conversation];
            } else {
                [self processMemberLeaveEvent:event forConversation:conversation];
            }
            [self shouldDeleteConversation:conversation ifSelfUserLeftWithEvent:event];
            break;
        case ZMUpdateEventTypeConversationMemberUpdate:
            [self processMemberUpdateEvent:event forConversation:conversation previousLastServerTimeStamp:previousLastServerTimestamp];
            break;
        case ZMUpdateEventTypeConversationConnectRequest:
            [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationAccessModeUpdate:
            [self processAccessModeUpdateEvent:event inConversation:conversation];
            break;       
        case ZMUpdateEventTypeConversationMessageTimerUpdate:
            [self processDestructionTimerUpdateEvent:event inConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationUpdateAutoreply:
            [self processConversationAutoReplyEvent:event forConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationChangeType:
            [self processConversationChangeTypeEvent:event forConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationChangeCreater:
            [self processConversationChangecreatorEvent:event forConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationUpdateAliasname:
            [self processConversationUpdateAliasnameEvent:event forConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationUpdate:
        {
            [self processUpdateEvent:event forConversation:conversation];
            break;
        }
        case ZMUpdateEventTypeConversationAppMessageAdd:
            [self processConversationAppMessageAddEvent:event forConversation:conversation];
            break;
        case ZMUpdateEventTypeConversationReceiptModeUpdate:
            [self processReceiptModeUpdate:event inConversation:conversation lastServerTimestamp:previousLastServerTimestamp];
        default:
            break;
    }
}


- (void)processConversationChangeTypeEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation
{
    NSDictionary *data = [event.payload dictionaryForKey:@"data"];
    NSNumber *type = data[@"type"];
    if ([type isEqualToNumber: [NSNumber numberWithInt:5]]) {
        conversation.conversationType = ZMConversationTypeHugeGroup;
        conversation.localMessageDestructionTimeout = 0;
        conversation.syncedMessageDestructionTimeout = 0;
    }
}


- (void)processConversationChangecreatorEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation {
    NSDictionary *data = [event.payload dictionaryForKey:@"data"];
    //    NSString *type = data[@"creator"];
    NSUUID *creatorId = [data uuidForKey:@"creator"];
    if(creatorId != nil) {
        conversation.creator = [ZMUser userWithRemoteID:creatorId createIfNeeded:YES inConversation:conversation inContext:self.managedObjectContext];
    }
}

- (void)processConversationAppMessageAddEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation {
    NSString *userid = [event.payload optionalStringForKey:@"from"];
    if (userid && userid.length > 0 && [userid.lowercaseString isEqualToString:[ZMUser selfUserInContext:self.managedObjectContext].remoteIdentifier.transportString]) {
        return;
    }
    
    NSDictionary *data = [event.payload dictionaryForKey:@"data"];
    NSString *msgType = [data optionalStringForKey:@"msgType"];
    if ([msgType isEqualToString:@"20032"]) {
        NSDictionary *msgData = [data dictionaryForKey:@"msgData"];
        [[NSNotificationCenter defaultCenter] postNotificationName:ConversationApplyToTestNotification object:nil userInfo:msgData];
        return;
    }
    
    [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
}



- (void)processConversationAutoReplyEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation
{
    NSDictionary *data = [event.payload dictionaryForKey:@"data"];
    short newAutoReply = [[data numberForKey:@"auto_reply"] shortValue];

    BOOL senderIsSelfUser = ([event.senderUUID isEqual:[ZMUser selfUserInContext:self.managedObjectContext].remoteIdentifier]);
    if (senderIsSelfUser) {
        conversation.autoReply = newAutoReply;
//        conversation.autoReplyChangedTimestamp = date;
    }else{
        conversation.autoReplyFromOther = newAutoReply;
//        conversation.autoReplyFromOtherChangedTimestamp = date;
    }
    
}

- (void)processConversationUpdateAliasnameEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation
{
    NSString *fromId = [event.payload optionalStringForKey:@"from"];
    NSDictionary *data = [event.payload dictionaryForKey:@"data"];
    NSString *aliname = [data optionalStringForKey:@"alias_name_ref"];
    [UserAliasname updateFromAliasName:aliname remoteIdentifier:[fromId lowercaseString] managedObjectContext:self.managedObjectContext inConversation:conversation];
}

- (void)processConversationRenameEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation
{
    NSDictionary *data = [event.payload dictionaryForKey:@"data"];
    NSString *newName = [data stringForKey:@"name"];
    
    if (![conversation.userDefinedName isEqualToString:newName] || [conversation.modifiedKeys containsObject:ZMConversationUserDefinedNameKey]) {
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    
    conversation.userDefinedName = newName;
}


- (void)processMemberJoinEvent:(ZMUpdateEvent *)event forHugeConversation:(ZMConversation *)hugeConversation
{
    if (!hugeConversation.remoteIdentifier.transportString) {
        return;
    }
    
    [ZMSystemMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.managedObjectContext];
    
    [self assignMembersCountWithEvent:event forConversation:hugeConversation];
}
    
- (void)processMemberJoinEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation
{
    NSSet *users = [event usersFromUserIDsInManagedObjectContext:self.managedObjectContext createIfNeeded:YES];
    
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    
    if (![users isSubsetOfSet:conversation.activeParticipants] || (selfUser && [users intersectsSet:[NSSet setWithObject:selfUser]])) {
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    
    for (ZMUser *user in users) {
        [conversation internalAddParticipants:@[user]];
    }
    
    [self assignMembersCountWithEvent:event forConversation:conversation];
}


- (void)processMemberLeaveEvent:(ZMUpdateEvent *)event forHugeConversation:(ZMConversation *)hugeConversation
{
    [self appendSystemMessageForUpdateEvent:event inConversation:hugeConversation];

    NSUUID *senderUUID = event.senderUUID;
    ZMUser *sender = [ZMUser userWithRemoteID:senderUUID createIfNeeded:YES inConversation:hugeConversation inContext:self.managedObjectContext];
    NSSet *users = [event usersFromUserIDsInManagedObjectContext:self.managedObjectContext createIfNeeded:NO];
    for (ZMUser *user in users) {
        [hugeConversation internalRemoveParticipants:@[user] sender: sender];
        [UserDisableSendMsgStatus deleteWithManagedObjectContext: self.managedObjectContext conversationId: hugeConversation.remoteIdentifier.transportString userId: user.remoteIdentifier.transportString];
    }
    
    [self assignMembersCountWithEvent:event forConversation:hugeConversation];
}

- (void)processMemberLeaveEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation
{
    NSUUID *senderUUID = event.senderUUID;
    ZMUser *sender = [ZMUser userWithRemoteID:senderUUID createIfNeeded:YES inConversation:conversation inContext:self.managedObjectContext];
    NSSet *users = [event usersFromUserIDsInManagedObjectContext:self.managedObjectContext createIfNeeded:YES];
    
    if (!conversation.remoteIdentifier.transportString || users.count == 0) {
        return;
    }
    ZMLogDebug(@"processMemberLeaveEvent (%@) leaving users.count = %lu", conversation.remoteIdentifier.transportString, (unsigned long)users.count);
    
    if ([users intersectsSet:conversation.activeParticipants]) {
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }

    for (ZMUser *user in users) {
        [conversation internalRemoveParticipants:@[user] sender:sender];
        [UserDisableSendMsgStatus deleteWithManagedObjectContext: self.managedObjectContext conversationId:conversation.remoteIdentifier.transportString userId:user.remoteIdentifier.transportString];
    }
    
    [self assignMembersCountWithEvent:event forConversation:conversation];
}
    
- (void)assignMembersCountWithEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation {
    if (conversation.conversationType == ZMConversationTypeHugeGroup) {
        NSDictionary *data = [event.payload dictionaryForKey:@"data"];
        NSNumber *membersCountNumber = [data optionalNumberForKey:@"memsum"];
        if (membersCountNumber != nil) {
            conversation.membersCount = membersCountNumber.integerValue;
        }
    }
    else {
        conversation.membersCount = (NSInteger)conversation.activeParticipants.count;
    }
}

- (void)shouldDeleteConversation: (ZMConversation *)conversation ifSelfUserLeftWithEvent: (ZMUpdateEvent *)event {
    NSDictionary *data = [event.payload dictionaryForKey:@"data"];
    NSArray *leavingUserIds = [data optionalArrayForKey:@"user_ids"];
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    if ([leavingUserIds containsObject:selfUser.remoteIdentifier.transportString]) {
        [conversation deleteConversation];
    }
}

- (void)processUpdateEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation
{
    NSDictionary *dataPayload = [event.payload.asDictionary dictionaryForKey:@"data"];
    if(dataPayload == NULL) {
        return;
    }

    if ([dataPayload.allKeys containsObject:ZMConversationEnabledEditMsgKey] && dataPayload[ZMConversationEnabledEditMsgKey] != nil) {
        conversation.enabledEditMsg = [dataPayload[ZMConversationEnabledEditMsgKey] boolValue];
    }

    if ([dataPayload.allKeys containsObject:ZMConversationShowMemsumKey] && dataPayload[ZMConversationShowMemsumKey] != nil) {
        conversation.showMemsum = [dataPayload[ZMConversationShowMemsumKey] boolValue];
    }

    if ([dataPayload.allKeys containsObject:@"viewmem"] && dataPayload[@"viewmem"] != nil) {
        conversation.isAllowViewMembers = [dataPayload[@"viewmem"] boolValue];
    }

    if ([dataPayload.allKeys containsObject:@"url_invite"] && dataPayload[@"url_invite"] != nil) {
        conversation.isOpenUrlJoin = [dataPayload[@"url_invite"] boolValue];
    }

    if ([dataPayload.allKeys containsObject:@"confirm"] && dataPayload[@"confirm"] != nil) {
        conversation.isOpenCreatorInviteVerify = [dataPayload[@"confirm"] boolValue];
    }

    if ([dataPayload.allKeys containsObject:ZMConversationInfoMemberInviteVerfyKey] && dataPayload[ZMConversationInfoMemberInviteVerfyKey] != nil) {
        conversation.isOpenMemberInviteVerify = [dataPayload[ZMConversationInfoMemberInviteVerfyKey] boolValue];
    }
 
    if ([dataPayload.allKeys containsObject:@"addright"] && dataPayload[@"addright"] != nil) {
        conversation.isOnlyCreatorInvite = [dataPayload[@"addright"] boolValue];
    }

    if ([dataPayload.allKeys containsObject:@"new_creator"] && dataPayload[@"new_creator"] != nil) {
        
        ZMUser *user = [ZMUser userWithRemoteID:[NSUUID uuidWithTransportString:dataPayload[@"new_creator"]] createIfNeeded:YES inContext:self.managedObjectContext];
        conversation.creator = user;
        conversation.creatorChangeTimestamp = [NSDate date];
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    
    
    if ([dataPayload.allKeys containsObject:ZMConversationInfoIsMessageVisibleOnlyManagerAndCreatorKey]) {
        conversation.isMessageVisibleOnlyManagerAndCreator = [dataPayload[ZMConversationInfoIsMessageVisibleOnlyManagerAndCreatorKey] boolValue];
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    

    if ([dataPayload.allKeys containsObject:ZMConversationInfoAnnouncementKey]) {
        conversation.announcement = [dataPayload optionalStringForKey:ZMConversationInfoAnnouncementKey];
        conversation.isReadAnnouncement = NO;
    }
    

    if ([dataPayload.allKeys containsObject:@"assets"] && dataPayload[@"assets"] != nil) {
        NSArray *asstes = dataPayload[@"assets"];
        for (NSDictionary *imgDic in asstes) {
            if ([imgDic[@"size"] isEqualToString:@"complete"]) {
                conversation.groupImageMediumKey = imgDic[@"key"];
            }
            if ([imgDic[@"size"] isEqualToString:@"preview"]) {
                conversation.groupImageSmallKey = imgDic[@"key"];
            }
        }
    }

    if ([dataPayload.allKeys containsObject:@"forumid"]) {
    
        NSNumber *forumIdNumber = [dataPayload optionalNumberForKey:@"forumid"];
        if (forumIdNumber != nil) {
            // Backend is sending the miliseconds, we need to convert to seconds.
            conversation.communityID = [forumIdNumber stringValue];
        }
    }
    

    if ([dataPayload.allKeys containsObject:ZMConversationInfoIsAllowMemberAddEachOtherKey]) {
        conversation.isAllowMemberAddEachOther = [dataPayload[ZMConversationInfoIsAllowMemberAddEachOtherKey] boolValue];
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }

//    if([dataPayload.allKeys containsObject:ZMConversationPersonalEnableEditMsgKey]) {
//        conversation.isEnabledEditPersonalMsg = !([dataPayload[ZMConversationPersonalEnableEditMsgKey] integerValue] == 0);
//        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
//    }
  
    if ([dataPayload.allKeys containsObject:ZMConversationInfoIsVisibleForMemberChangeKey]) {
        conversation.isVisibleForMemberChange = [dataPayload[ZMConversationInfoIsVisibleForMemberChangeKey] boolValue];
    }
    
  
    if([dataPayload.allKeys containsObject:ZMConversationInfoBlockTimeKey]) {
        conversation.isDisableSendMsg = !([dataPayload[ZMConversationInfoBlockTimeKey] integerValue] == 0);
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    

    if([dataPayload.allKeys containsObject:ZMConversationShowMemsumKey]) {
        conversation.showMemsum = !([dataPayload[ZMConversationShowMemsumKey] integerValue] == 0);
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    

    if([dataPayload.allKeys containsObject:ZMConversationEnabledEditMsgKey]) {
        conversation.enabledEditMsg = !([dataPayload[ZMConversationEnabledEditMsgKey] integerValue] == 0);
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }


    if([dataPayload.allKeys containsObject:ZMConversationInfoOpenScreenShotKey]) {
        conversation.isOpenScreenShot = !([dataPayload[ZMConversationInfoOpenScreenShotKey] integerValue] == 0);
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    

    if([dataPayload.allKeys containsObject:ZMCOnversationInfoOTRAllowViewMembersKey]) {
        conversation.isAllowViewMembers = !([dataPayload[ZMCOnversationInfoOTRAllowViewMembersKey] integerValue] == 0);
        [self appendSystemMessageForUpdateEvent:event inConversation:conversation];
    }
    

    if([dataPayload.allKeys containsObject:ZMConversationBlockedKey]) {
        conversation.blocked = !([dataPayload[ZMConversationBlockedKey] integerValue] == 0);
    }
    
    if([dataPayload.allKeys containsObject:ZMConversationAssistantBotKey] && [dataPayload.allKeys containsObject:ZMConversationAssistantBotOptKey]) {
        if([dataPayload optionalNumberForKey:ZMConversationAssistantBotOptKey].integerValue == 0) {
            conversation.assistantBot = nil;
        } else if ([dataPayload optionalNumberForKey:ZMConversationAssistantBotOptKey].integerValue == 1) {
            NSString *bid = [dataPayload optionalStringForKey:ZMConversationAssistantBotKey];
            ZMUser *botUser = [ZMUser userWithRemoteID:[NSUUID uuidWithTransportString:bid] createIfNeeded:false inContext:self.managedObjectContext];
            botUser.needsToBeUpdatedFromBackend = true;
            conversation.assistantBot = bid;
        }
    }
    
    if ([dataPayload.allKeys containsObject:ZMConversationInfoOratorKey]) {
        NSArray *orator = [dataPayload optionalArrayForKey:ZMConversationInfoOratorKey];
        if (!orator) {
            return;
        }
        for (NSString* obj in orator) {
            ZMUser *user = [ZMUser userWithRemoteID:[NSUUID uuidWithTransportString:obj] createIfNeeded:YES inContext:self.managedObjectContext];
            user.needsToBeUpdatedFromBackend = YES;
        }
        conversation.orator = orator.set;
    }

    if ([dataPayload.allKeys containsObject:ZMConversationInfoManagerKey]) {
        NSArray *manager = [dataPayload optionalArrayForKey:ZMConversationInfoManagerKey];
        conversation.manager = manager.set;
        
        conversation.managerAdd = [[NSSet alloc] init];
        conversation.managerDel = [[NSSet alloc] init];
        NSArray *addUsers = [dataPayload optionalArrayForKey:ZMConversationInfoManagerAddKey];
        NSArray *delUsers = [dataPayload optionalArrayForKey:ZMConversationInfoManagerDelKey];
        
        NSString *selfUserUUIDString = [ZMUser selfUserInContext:self.managedObjectContext].remoteIdentifier.transportString;
        for (NSDictionary *userDict in [addUsers asDictionaries]) {
            NSString *userId = [userDict stringForKey:@"id"];
            if (userId == nil) {
                continue;
            }
            NSString * name = [userDict stringForKey:@"name"];
            if ([userId isEqualToString:selfUserUUIDString]) {
                [self appendManagerSystemMessageForUpdateEvent:event inConversation:conversation withManagerType:ZMSystemManagerMessageTypeMeBecameManager name:name];
            } else {
                if (!name) {
                    name = [userDict stringForKey:@"handle"];
                }
                [self appendManagerSystemMessageForUpdateEvent:event inConversation:conversation withManagerType:ZMSystemManagerMessageTypeOtherBecameManager name:name];
            }
        }
        for (NSDictionary *userDict in [delUsers asDictionaries]) {
            NSString *userId = [userDict stringForKey:@"id"];
            if (userId == nil) {
                continue;
            }
            NSString * name = [userDict stringForKey:@"name"];
            if ([userId isEqualToString:selfUserUUIDString]) {
                [self appendManagerSystemMessageForUpdateEvent:event inConversation:conversation withManagerType:ZMSystemManagerMessageTypeMeDropManager name:name];
            } else {
                if (!name) {
                    name = [userDict stringForKey:@"handle"];
                }
                [self appendManagerSystemMessageForUpdateEvent:event inConversation:conversation withManagerType:ZMSystemManagerMessageTypeOtherDropManager name:name];
            }
        }
    }
    
}

- (void)processMemberUpdateEvent:(ZMUpdateEvent *)event forConversation:(ZMConversation *)conversation previousLastServerTimeStamp:(NSDate *)previousLastServerTimestamp
{
    NSDictionary *dataPayload = [event.payload.asDictionary dictionaryForKey:@"data"];
 
    if(dataPayload) {
        [conversation updateSelfStatusFromDictionary:dataPayload
                                           timeStamp:event.timeStamp
                         previousLastServerTimeStamp:previousLastServerTimestamp];
    }
}

- (void)appendManagerSystemMessageForUpdateEvent:(ZMUpdateEvent *)event inConversation:(ZMConversation *)conversation withManagerType:(ZMSystemManagerMessageType)type name:(NSString *)name
{
    ZMSystemMessage *systemMessage = [ZMSystemMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.managedObjectContext];
    systemMessage.managerType = type;
    systemMessage.text = name;
    
    if (systemMessage != nil) {
        [self.localNotificationDispatcher processMessage:systemMessage];
    }
}


- (void)appendSystemMessageForUpdateEvent:(ZMUpdateEvent *)event inConversation:(ZMConversation * ZM_UNUSED)conversation
{
    ZMSystemMessage *systemMessage = [ZMSystemMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.managedObjectContext];
    
    if (systemMessage != nil) {
        [self.localNotificationDispatcher processMessage:systemMessage];
    }
}

@end



@implementation ZMConversationTranscoder (UpstreamTranscoder)

- (BOOL)shouldProcessUpdatesBeforeInserts;
{
    return NO;
}

- (ZMUpstreamRequest *)requestForUpdatingObject:(ZMConversation *)updatedConversation forKeys:(NSSet *)keys;
{
    ZMUpstreamRequest *request = nil;
    if([keys containsObject:ZMConversationUserDefinedNameKey]) {
        request = [self requestForUpdatingUserDefinedNameInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationAutoReplyKey]) {
        request = [self requestForUpdatingAutoReplyInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationSelfRemarkKey]) {
        request = [self requestForUpdatingSelfRemarkInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationIsOpenCreatorInviteVerifyKey]) {
        request = [self requestForUpdatingIsOpenCreatorInviteVerifyInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationIsOpenMemberInviteVerifyKey]) {
        request = [self requestForUpdatingIsOpenMemberInviteVerifyInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationOnlyCreatorInviteKey]) {
        request = [self requestForUpdatingOnlyCreatorInviteInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationOpenUrlJoinKey]) {
        request = [self requestForUpdatingOpenUrlJoinInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationAllowViewMembersKey]) {
        request = [self requestForUpdatingAllowViewMembersInConversation:updatedConversation];
    }
    if([keys containsObject:CreatorKey]) {
        request = [self requestForUpdatingCreatorInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationIsDisableSendMsgKey]) {
        request = [self requestForUpdatingDisableSendMsgInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationIsAllowMemberAddEachOtherKey]) {
        request = [self requestForUpdatingMemberAddInConversation:updatedConversation];
    }
    if([keys containsObject:ZMConversationIsVisibleForMemberChangeKey]) {
        request = [self requestForUpdatingVisibleForMemberChangeInConversation:updatedConversation];
    }
    if ([keys containsObject:ZMConversationInfoOratorKey]) {
        request = [self requestForUpdatingOratorInConversation:updatedConversation];
    }
    if ([keys containsObject:ZMConversationManagerAddKey]) {
        request = [self requestForAddManagerInConversation:updatedConversation];
    }
    if ([keys containsObject:ZMConversationManagerDelKey]) {
        request = [self requestForDelManagerInConversation:updatedConversation];
    }
    if ([keys containsObject:ZMConversationIsMessageVisibleOnlyManagerAndCreatorKey]) {
        request = [self requestForUpdatingIsMessageVisibleOnlyManagerAndCreatorInConversation:updatedConversation];
    }
    if ([keys containsObject:ZMConversationAnnouncementKey]) {
        request = [self requestForUpdatingAnnouncementInConversation:updatedConversation];
    }
    if ([keys containsObject:ZMConversationPreviewAvatarKey] && [keys containsObject:ZMConversationCompleteAvatarKey]) {
        request = [self requestForBindAvatarKeyInConversation:updatedConversation];
    }
    if ([keys containsObject:ShowMemsumKey]) {
        request = [self requestForUpdatingShowMemsumInConversation:updatedConversation];
    }
    if ([keys containsObject:EnabledEditMsgKey]) {
        request = [self requestForUpdatingEnabledEditMsgInConversation:updatedConversation];
    }

//    if ([keys containsObject:EnabledEditPersonalMsgKey]) {
//        request = [self requestForUpdatingPersonalEnabledEditMsgInConversation:updatedConversation];
//    }
    
    if ([keys containsObject:ZMConversationInfoOpenScreenShotKey]) {
        request = [self requestForUpdatingOpenScreenShotInConversation:updatedConversation];
    }
    
    if (request == nil && (   [keys containsObject:ZMConversationArchivedChangedTimeStampKey]
                           || [keys containsObject:ZMConversationSilencedChangedTimeStampKey]
                           || [keys containsObject:ZMConversationIsPlacedTopKey])) {
        request = [updatedConversation requestForUpdatingSelfInfo];
    }
    if (request == nil) {
        ZMTrapUnableToGenerateRequest(keys, self);
    }
    return request;
}

- (ZMUpstreamRequest *)requestForUpdatingUserDefinedNameInConversation:(ZMConversation *)conversation
{
    NSDictionary *payload = @{ @"name" : conversation.userDefinedName };
    NSString *lastComponent = conversation.remoteIdentifier.transportString;
    Require(lastComponent != nil);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, lastComponent]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];

    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationUserDefinedNameKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingAutoReplyInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = @{ @"auto_reply" : @(conversation.autoReply)}.mutableCopy;
    NSString *lastComponent = conversation.remoteIdentifier.transportString;
    Require(lastComponent != nil);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, lastComponent, @"autoreply"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    
    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationAutoReplyKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingSelfRemarkInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    payload[ZMConversationInfoOTRSelfRemarkReferenceKey] = conversation.selfRemark;
    payload[ZMConversationInfoOTRSelfRemarkBoolKey] = @(YES);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"selfalias"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationSelfRemarkKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingIsOpenCreatorInviteVerifyInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    payload[ZMConversationInfoOTRSelfVerifyKey] = @(conversation.isOpenCreatorInviteVerify);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationIsOpenCreatorInviteVerifyKey] transportRequest:request userInfo:nil];
}
    
- (ZMUpstreamRequest *)requestForUpdatingIsOpenMemberInviteVerifyInConversation:(ZMConversation *)conversation
    {
        NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
        payload[ZMConversationInfoMemberInviteVerfyKey] = @(conversation.isOpenMemberInviteVerify);
        NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
        ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
        return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationIsOpenMemberInviteVerifyKey] transportRequest:request userInfo:nil];
    }

- (ZMUpstreamRequest *)requestForUpdatingOnlyCreatorInviteInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    payload[ZMConversationInfoOTRCanAddKey] = @(conversation.isOnlyCreatorInvite);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationOnlyCreatorInviteKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingOpenUrlJoinInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    payload[ZMCOnversationInfoOTROpenUrlJoinKey] = @(conversation.isOpenUrlJoin);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationOpenUrlJoinKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingAllowViewMembersInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    payload[ZMCOnversationInfoOTRAllowViewMembersKey] = @(conversation.isAllowViewMembers);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationAllowViewMembersKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingCreatorInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    payload[ZMConversationInfoOTRCreatorChangeKey] = conversation.creator.remoteIdentifier.transportString;
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:CreatorKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingDisableSendMsgInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    payload[ZMConversationInfoBlockTimeKey] = @(conversation.isDisableSendMsg ? -1 : 0);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationIsDisableSendMsgKey] transportRequest:request userInfo:nil];
}


- (ZMUpstreamRequest *)requestForUpdatingMemberAddInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];

    payload[ZMConversationInfoIsAllowMemberAddEachOtherKey] = @(conversation.isAllowMemberAddEachOther);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationIsAllowMemberAddEachOtherKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingOpenScreenShotInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];

    payload[ZMConversationInfoOpenScreenShotKey] = @(conversation.isOpenScreenShot);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationInfoOpenScreenShotKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingVisibleForMemberChangeInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];

    payload[ZMConversationInfoIsVisibleForMemberChangeKey] = @(conversation.isVisibleForMemberChange);
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationIsVisibleForMemberChangeKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForUpdatingOratorInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    
    payload[ZMConversationInfoOratorKey] = [conversation.orator allObjects];
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationInfoOratorKey] transportRequest:request userInfo:nil];
}

- (ZMUpstreamRequest *)requestForAddManagerInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    
    payload[ZMConversationInfoManagerAddKey] = [conversation.managerAdd allObjects];
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationManagerAddKey] transportRequest:request userInfo:nil];
}
- (ZMUpstreamRequest *)requestForDelManagerInConversation:(ZMConversation *)conversation
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    
    payload[ZMConversationInfoManagerDelKey] = [conversation.managerDel allObjects];
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationManagerDelKey] transportRequest:request userInfo:nil];
}


- (ZMUpstreamRequest *)requestForUpdatingIsMessageVisibleOnlyManagerAndCreatorInConversation:(ZMConversation *)conversation
{
    NSString *remoteIdComponent = conversation.remoteIdentifier.transportString;
    Require(remoteIdComponent != nil);
    NSDictionary *payload = @{ ZMConversationInfoIsMessageVisibleOnlyManagerAndCreatorKey : @(conversation.isMessageVisibleOnlyManagerAndCreator) };
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, remoteIdComponent, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationIsMessageVisibleOnlyManagerAndCreatorKey] transportRequest:request];
}
    

- (ZMUpstreamRequest *)requestForUpdatingAnnouncementInConversation:(ZMConversation *)conversation
{
    NSString *remoteIdComponent = conversation.remoteIdentifier.transportString;
    Require(remoteIdComponent != nil);
    NSDictionary *payload = @{ ZMConversationInfoAnnouncementKey : conversation.announcement };
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, remoteIdComponent, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:ZMConversationAnnouncementKey] transportRequest:request];
}


- (ZMUpstreamRequest *)requestForBindAvatarKeyInConversation:(ZMConversation *)conversation
{
    NSString *remoteIdComponent = conversation.remoteIdentifier.transportString;
    Require(remoteIdComponent != nil);
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"assets"] = [self avatarPictureAssetsPayloadForConversation:conversation];
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, remoteIdComponent, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObjects:ZMConversationPreviewAvatarKey, ZMConversationCompleteAvatarKey, nil] transportRequest:request];
}


- (ZMUpstreamRequest *)requestForUpdatingShowMemsumInConversation:(ZMConversation *)conversation
{
    NSString *remoteIdComponent = conversation.remoteIdentifier.transportString;
    Require(remoteIdComponent != nil);
    NSDictionary *payload = @{ ZMConversationShowMemsumKey : @(conversation.showMemsum) };
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, remoteIdComponent, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject: ShowMemsumKey] transportRequest:request];
}


- (ZMUpstreamRequest *)requestForUpdatingEnabledEditMsgInConversation:(ZMConversation *)conversation
{
    NSString *remoteIdComponent = conversation.remoteIdentifier.transportString;
    Require(remoteIdComponent != nil);
    NSDictionary *payload = @{ ZMConversationEnabledEditMsgKey : @(conversation.enabledEditMsg) };
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, remoteIdComponent, @"update"]];
    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:EnabledEditMsgKey] transportRequest:request];
}

//- (ZMUpstreamRequest *)requestForUpdatingPersonalEnabledEditMsgInConversation:(ZMConversation *)conversation
//{
//    NSString *remoteIdComponent = conversation.remoteIdentifier.transportString;
//    Require(remoteIdComponent != nil);
//    NSDictionary *payload = @{ ZMConversationPersonalEnableEditMsgKey : @(conversation.isEnabledEditPersonalMsg) };
//    NSString *path = [NSString pathWithComponents:@[ConversationsPath, remoteIdComponent, @"update"]];
//    ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:ZMMethodPUT payload:payload];
//    [request expireAfterInterval:ZMTransportRequestDefaultExpirationInterval];
//    return [[ZMUpstreamRequest alloc] initWithKeys:[NSSet setWithObject:EnabledEditPersonalMsgKey] transportRequest:request];
//}

- (NSArray *)avatarPictureAssetsPayloadForConversation:(ZMConversation *)conversation {
    return @[
             @{
                 @"size" : @"preview",
                 @"key"  : conversation.groupImageSmallKey,
                 @"type" : @"image"
                 },
             @{
                 @"size" : @"complete",
                 @"key"  : conversation.groupImageMediumKey,
                 @"type" : @"image"
                 },
             ];
}


- (ZMUpstreamRequest *)requestForInsertingObject:(ZMManagedObject *)managedObject forKeys:(NSSet *)keys;
{
    NOT_USED(keys);
    
    ZMTransportRequest *request = nil;
    ZMConversation *insertedConversation = (ZMConversation *) managedObject;
    
    NSArray *participantUUIDs = [[insertedConversation.lastServerSyncedActiveParticipants array] mapWithBlock:^id(ZMUser *user) {
        return [user.remoteIdentifier transportString];
    }];
    
    NSMutableDictionary *payload = [@{ @"users" : participantUUIDs } mutableCopy];
    if (insertedConversation.userDefinedName != nil) {
        payload[@"name"] = insertedConversation.userDefinedName;
    }

   
    if (insertedConversation.conversationType == ZMConversationTypeHugeGroup) {
        payload[@"type"] = [NSNumber numberWithInteger: 5];
    }
    
    if (insertedConversation.hasReadReceiptsEnabled) {
        payload[@"receipt_mode"] = @(1);
    }

    if (insertedConversation.team.remoteIdentifier != nil) {
        payload[ConversationTeamKey] = @{
                             ConversationTeamIdKey: insertedConversation.team.remoteIdentifier.transportString,
                             ConversationTeamManagedKey: @NO // FIXME:
                             };
    }

    NSArray <NSString *> *accessPayload = insertedConversation.accessPayload;
    if (nil != accessPayload) {
        payload[ConversationAccessKey] = accessPayload;
    }

    NSString *accessRolePayload = insertedConversation.accessRolePayload;
    if (nil != accessRolePayload) {
        payload[ConversationAccessRoleKey] = accessRolePayload;
    }
    
    request = [ZMTransportRequest requestWithPath:ConversationsPath method:ZMMethodPOST payload:payload];
    return [[ZMUpstreamRequest alloc] initWithTransportRequest:request];
}


- (void)updateInsertedObject:(ZMManagedObject *)managedObject request:(ZMUpstreamRequest *__unused)upstreamRequest response:(ZMTransportResponse *)response
{
    ZMConversation *insertedConversation = (ZMConversation *)managedObject;
    NSUUID *remoteID = [response.payload.asDictionary uuidForKey:@"id"];
    
    // check if there is another with the same conversation ID
    if (remoteID != nil) {
        ZMConversation *existingConversation = [ZMConversation conversationWithRemoteID:remoteID createIfNeeded:NO inContext:self.managedObjectContext];
        
        if (existingConversation != nil) {
            [self.managedObjectContext deleteObject:existingConversation];
            insertedConversation.needsToBeUpdatedFromBackend = YES;
        }
    }
    insertedConversation.remoteIdentifier = remoteID;
    [insertedConversation updateWithTransportData:response.payload.asDictionary serverTimeStamp:nil];
}

- (ZMUpdateEvent *)conversationEventWithKeys:(NSSet *)keys responsePayload:(id<ZMTransportData>)payload;
{
    NSSet *keysThatGenerateEvents = [NSSet setWithObjects:ZMConversationUserDefinedNameKey,ZMConversationSelfRemarkKey, nil];
    
    if (! [keys intersectsSet:keysThatGenerateEvents]) {
        return nil;
        
    }

    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    return event;
}


- (BOOL)updateUpdatedObject:(ZMConversation *)conversation
            requestUserInfo:(NSDictionary *)userInfo
                   response:(ZMTransportResponse *)response
                keysToParse:(NSSet *)keysToParse
{
    NOT_USED(conversation);
    
    ZMUpdateEvent *event = [self conversationEventWithKeys:keysToParse responsePayload:response.payload];
    if (event != nil) {
        [self processEvents:@[event] liveEvents:YES prefetchResult:nil];
    }
        
    if ([keysToParse isEqualToSet:[NSSet setWithObject:ZMConversationUserDefinedNameKey]]) {
        return NO;
    }
    
    if( keysToParse == nil ||
       [keysToParse isEmpty] ||
       [keysToParse containsObject:ZMConversationSilencedChangedTimeStampKey] ||
       [keysToParse containsObject:ZMConversationArchivedChangedTimeStampKey])
    {
        return NO;
    }
    ZMLogError(@"Unknown changed keys in request. keys: %@  payload: %@  userInfo: %@", keysToParse, response.payload, userInfo);
    return NO;
}

- (ZMManagedObject *)objectToRefetchForFailedUpdateOfObject:(ZMManagedObject *)managedObject;
{
    if([managedObject isKindOfClass:ZMConversation.class]) {
        return managedObject;
    }
    return nil;
}

- (void)requestExpiredForObject:(ZMConversation *)conversation forKeys:(NSSet *)keys
{
    NOT_USED(keys);
    conversation.needsToBeUpdatedFromBackend = YES;
    [self resetModifiedKeysWithoutReferenceInConversation:conversation];
}

- (BOOL)shouldCreateRequestToSyncObject:(ZMManagedObject *)managedObject forKeys:(NSSet<NSString *> * __unused)keys  withSync:(id)sync;
{
    if (sync == self.downstreamSync || sync == self.insertedSync) {
        return YES;
    }
    // This is our chance to reset keys that should not be set - instead of crashing when we create a request.
    ZMConversation *conversation = (ZMConversation *)managedObject;
    NSMutableSet *remainingKeys = [NSMutableSet setWithSet:keys];
    
    if ([conversation hasLocalModificationsForKey:ZMConversationUserDefinedNameKey] && !conversation.userDefinedName) {
        [conversation resetLocallyModifiedKeys:[NSSet setWithObject:ZMConversationUserDefinedNameKey]];
        [remainingKeys removeObject:ZMConversationUserDefinedNameKey];
    }
    
    
    BOOL previewAvatarKeyChanged = [conversation hasLocalModificationsForKey:ZMConversationPreviewAvatarKey];
    BOOL completeAvatarKeyChanged = [conversation hasLocalModificationsForKey:ZMConversationCompleteAvatarKey];
   
    if ((int)(previewAvatarKeyChanged) + (int)(completeAvatarKeyChanged) == 1) {
       
        if (previewAvatarKeyChanged) {
            [conversation resetLocallyModifiedKeys:[NSSet setWithObject:ZMConversationPreviewAvatarKey]];
            [remainingKeys removeObject:ZMConversationPreviewAvatarKey];
        }
        if (completeAvatarKeyChanged) {
            [conversation resetLocallyModifiedKeys:[NSSet setWithObject:ZMConversationCompleteAvatarKey]];
            [remainingKeys removeObject:ZMConversationCompleteAvatarKey];
        }
    } else if (previewAvatarKeyChanged && completeAvatarKeyChanged && (!conversation.groupImageSmallKey || !conversation.groupImageMediumKey)) {
        
        [conversation resetLocallyModifiedKeys:[NSSet setWithObjects:ZMConversationPreviewAvatarKey, ZMConversationCompleteAvatarKey, nil]];
        [remainingKeys removeObject:ZMConversationPreviewAvatarKey];
        [remainingKeys removeObject:ZMConversationCompleteAvatarKey];
    }

    if (remainingKeys.count < keys.count) {
        [(id<ZMContextChangeTracker>)sync objectsDidChange:[NSSet setWithObject:conversation]];
        [self.managedObjectContext enqueueDelayedSave];
    }
    return (remainingKeys.count > 0);
}

- (BOOL)shouldRetryToSyncAfterFailedToUpdateObject:(ZMConversation *)conversation request:(ZMUpstreamRequest *__unused)upstreamRequest response:(ZMTransportResponse *__unused)response keysToParse:(NSSet * __unused)keys
{
    if (conversation.remoteIdentifier) {
        conversation.needsToBeUpdatedFromBackend = YES;
        [self resetModifiedKeysWithoutReferenceInConversation:conversation];
        [self.downstreamSync objectsDidChange:[NSSet setWithObject:conversation]];
    }
    
    return NO;
}

/// Resets all keys that don't have a time reference and would possibly be changed with refetching of the conversation from the BE
- (void)resetModifiedKeysWithoutReferenceInConversation:(ZMConversation*)conversation
{
    [conversation resetLocallyModifiedKeys:[NSSet setWithArray:self.keysToSyncWithoutRef]];
    
    // since we reset all keys, we should make sure to remove the object from the modifiedSync
    // it might otherwise try to sync remaining keys
    [self.modifiedSync objectsDidChange:[NSSet setWithObject:conversation]];
}

@end



@implementation ZMConversationTranscoder (DownstreamTranscoder)

- (ZMTransportRequest *)requestForFetchingObject:(ZMConversation *)conversation downstreamSync:(id<ZMObjectSync>)downstreamSync;
{
    NOT_USED(downstreamSync);
    if (conversation.remoteIdentifier == nil) {
        return nil;
    }
    
    NSString *path = [NSString pathWithComponents:@[ConversationsPath, conversation.remoteIdentifier.transportString]];
    ZMTransportRequest *request = [[ZMTransportRequest alloc] initWithPath:path method:ZMMethodGET payload:nil];
    return request;
}

- (void)updateObject:(ZMConversation *)conversation withResponse:(ZMTransportResponse *)response downstreamSync:(id<ZMObjectSync>)downstreamSync;
{
    NOT_USED(downstreamSync);
    conversation.needsToBeUpdatedFromBackend = NO;
    [self resetModifiedKeysWithoutReferenceInConversation:conversation];
    
    NSDictionary *dictionaryPayload = [response.payload asDictionary];
    VerifyReturn(dictionaryPayload != nil);
    [conversation updateWithTransportData:dictionaryPayload serverTimeStamp:nil];
}

- (void)deleteObject:(ZMConversation *)conversation withResponse:(ZMTransportResponse *)response downstreamSync:(id<ZMObjectSync>)downstreamSync;
{
    // Self user has been removed from the group conversation but missed the conversation.member-leave event.
    if (response.HTTPStatus == 403 && conversation.conversationType == ZMConversationTypeGroup && conversation.isSelfAnActiveMember) {
        ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
        [conversation internalRemoveParticipants:@[selfUser] sender:selfUser];
    }
    
    // Conversation has been permanently deleted
    if (response.HTTPStatus == 404 && conversation.conversationType == ZMConversationTypeGroup) {
        [self.managedObjectContext deleteObject:conversation];
    }
    
    if (response.isPermanentylUnavailableError) {
        conversation.needsToBeUpdatedFromBackend = NO;
    }
    
    NOT_USED(downstreamSync);
}

@end


@implementation ZMConversationTranscoder (PaginatedRequest)

- (NSUInteger)maximumRemoteIdentifiersPerRequestForObjectSync:(ZMRemoteIdentifierObjectSync *)sync;
{
    NOT_USED(sync);
    return self.conversationPageSize;
}


- (ZMTransportRequest *)requestForObjectSync:(ZMRemoteIdentifierObjectSync *)sync remoteIdentifiers:(NSSet *)identifiers;
{
    NOT_USED(sync);
    
    NSArray *currentBatchOfConversationIDs = [[identifiers allObjects] mapWithBlock:^id(NSUUID *obj) {
        return obj.transportString;
    }];
    NSString *path = [NSString stringWithFormat:@"%@?ids=%@", ConversationsPath, [currentBatchOfConversationIDs componentsJoinedByString:@","]];

    return [[ZMTransportRequest alloc] initWithPath:path method:ZMMethodGET payload:nil];
}


- (void)didReceiveResponse:(ZMTransportResponse *)response remoteIdentifierObjectSync:(ZMRemoteIdentifierObjectSync *)sync forRemoteIdentifiers:(NSSet *)remoteIdentifiers;
{
    NOT_USED(sync);
    NOT_USED(remoteIdentifiers);
    NSDictionary *payload = [response.payload asDictionary];
    NSArray *conversations = [payload arrayForKey:@"conversations"];
    
    for (NSDictionary *rawConversation in [conversations asDictionaries]) {
        ZMConversation *conversation = [self createConversationFromTransportData:rawConversation serverTimeStamp:[NSDate date] source:ZMConversationSourceSlowSync];
        conversation.needsToBeUpdatedFromBackend = NO;
        
        if (conversation != nil) {
            [self.lastSyncedActiveConversations addObject:conversation];
        }
    }
    
    if (response.result == ZMTransportResponseStatusPermanentError && self.isSyncing) {
        [self.syncStatus failCurrentSyncPhaseWithPhase:self.expectedSyncPhase];
    }
    
    [self finishSyncIfCompleted];
}

@end
