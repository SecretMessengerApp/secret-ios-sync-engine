// 


@import WireUtilities;
@import WireSystem;
@import WireTransport;
@import WireCryptobox;
@import WireDataModel;

#import "ZMOperationLoop+Private.h"
#import "ZMSyncStrategy+ManagedObjectChanges.h"

#import "ZMUserTranscoder.h"
#import "ZMUserSession.h"
#import <libkern/OSAtomic.h>
#import <os/activity.h>
#import "WireSyncEngineLogs.h"
#import <WireSyncEngine/WireSyncEngine-Swift.h>

NSString * const ZMPushChannelIsOpenKey = @"pushChannelIsOpen";

static char* const ZMLogTag ZM_UNUSED = "OperationLoop";


@interface ZMOperationLoop ()
{
    int32_t _pendingEnqueueNextCount;
}

@property (nonatomic) NSNotificationQueue *enqueueNotificationQueue;
@property (nonatomic) id<TransportSessionType> transportSession;
@property (atomic) BOOL shouldStopEnqueueing;
@property (nonatomic) BOOL tornDown;
@property (nonatomic, weak) ApplicationStatusDirectory *applicationStatusDirectory;

@end


@interface ZMOperationLoop (NewRequests) <ZMRequestAvailableObserver>
@end


@implementation ZMOperationLoop

- (instancetype)initWithTransportSession:(id<TransportSessionType>)transportSession
                            syncStrategy:(ZMSyncStrategy *)syncStrategy
              applicationStatusDirectory:(ApplicationStatusDirectory *)applicationStatusDirectory
                                   uiMOC:(NSManagedObjectContext *)uiMOC
                                 syncMOC:(NSManagedObjectContext *)syncMOC
                                  msgMOC:(NSManagedObjectContext *)msgMOC
{
    Check(uiMOC != nil);
    Check(syncMOC != nil);
    Check(msgMOC != nil);
    
    self = [super init];
    if (self) {
        self.applicationStatusDirectory = applicationStatusDirectory;
        self.transportSession = transportSession;
        self.syncStrategy = syncStrategy;
        self.syncMOC = syncMOC;
        self.msgMOC = msgMOC;
        self.shouldStopEnqueueing = NO;
        applicationStatusDirectory.operationStatus.delegate = self;

        if (uiMOC != nil) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(userInterfaceContextDidSave:)
                                                         name:NSManagedObjectContextDidSaveNotification
                                                       object:uiMOC];
        }
        if (syncMOC != nil) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(syncContextDidSave:)
                                                         name:NSManagedObjectContextDidSaveNotification
                                                       object:syncMOC];
        }
        
        if (msgMOC != nil) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(msgContextDidSave:)
                                                         name:NSManagedObjectContextDidSaveNotification
                                                       object:msgMOC];
        }
        
        [ZMRequestAvailableNotification addObserver:self];
        
        [ZMRequestAvailableNotification addMsgObserver:self];
        
        NSManagedObjectContext *moc = self.syncMOC;
        // this is needed to avoid loading from syncMOC on the main queue
        [moc performGroupedBlock:^{
            [self.transportSession configurePushChannelWithConsumer:self groupQueue:moc];
            [self.transportSession.pushChannel setKeepOpen:applicationStatusDirectory.operationStatus.operationState == SyncEngineOperationStateForeground];
        }];
    }

    return self;
}

- (void)tearDown;
{
    self.tornDown = YES;
    self.shouldStopEnqueueing = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [ZMRequestAvailableNotification removeObserver:self];
    
    self.syncStrategy = nil;
    self.transportSession = nil;
    
    RequireString([NSOperationQueue mainQueue] == [NSOperationQueue currentQueue],
                  "Must call be called on the main queue.");
    __block BOOL didStop = NO;
    [self.syncMOC.dispatchGroup notifyOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) block:^{
        didStop = YES;
    }];
    while (!didStop) {
        if (! [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.002]]) {
            [NSThread sleepForTimeInterval:0.002];
        }
    }
    
    [self.msgMOC.dispatchGroup notifyOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) block:^{
        didStop = YES;
    }];
    while (!didStop) {
        if (! [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.002]]) {
            [NSThread sleepForTimeInterval:0.002];
        }
    }
}

#if DEBUG
- (void)dealloc
{
    RequireString(self.tornDown, "Did not call tearDown %p", (__bridge void *) self);
}
#endif


- (APSSignalingKeysStore *)apsSignalKeyStore
{
    if (_apsSignalKeyStore == nil) {
        ZMUser *selfUser = [ZMUser selfUserInContext:self.syncMOC];
        if (selfUser.selfClient != nil) {
            _apsSignalKeyStore = [[APSSignalingKeysStore alloc] initWithUserClient:selfUser.selfClient];
        }
    }
    return _apsSignalKeyStore;
}

+ (NSSet *)objectIDsetFromObject:(NSSet *)objects
{
    NSMutableSet *objectIds = [NSMutableSet set];
    for(NSManagedObject* obj in objects) {
        [objectIds addObject:obj.objectID];
    }
    return objectIds;
}

+ (NSSet *)objectSetFromObjectIDs:(NSSet *)objectIDs inContext:(NSManagedObjectContext *)moc
{
    NSMutableSet *objects = [NSMutableSet set];
    for(NSManagedObjectID *objId in objectIDs) {
        NSManagedObject *obj = [moc objectWithID:objId];
        if(obj) {
            [objects addObject:obj];
        }
    }
    return objects;
}

- (void)userInterfaceContextDidSave:(NSNotification *)note
{
    // We need to proceed even if those to sets are empty because the metadata might have been updated.

    ZM_WEAK(self);
    NSSet *uiInsertedObjects = note.userInfo[NSInsertedObjectsKey];
    NSSet *uiUpdatedObjects = note.userInfo[NSUpdatedObjectsKey];

    NSSet *messageInsertObjects = [uiInsertedObjects filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject isKindOfClass:[ZMClientMessage class]] ||
                [evaluatedObject isKindOfClass:[ZMAssetClientMessage class]] || [evaluatedObject isKindOfClass:[ZMGenericMessageData class]];
    }]];
 
    NSSet *messageUpdateObjects = [uiUpdatedObjects filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject isKindOfClass:[ZMClientMessage class]] ||
        [evaluatedObject isKindOfClass:[ZMAssetClientMessage class]] || [evaluatedObject isKindOfClass:[ZMGenericMessageData class]];
    }]];
   
    if (messageInsertObjects.count > 0 || messageUpdateObjects.count > 0) {
        NSSet *messageInsertObjectsIds = [ZMOperationLoop objectIDsetFromObject: messageInsertObjects];
        NSSet *messageUpdateObjectsIds = [ZMOperationLoop objectIDsetFromObject: messageUpdateObjects];
        [self.msgMOC performGroupedBlock:^{
            ZM_STRONG(self);
            NSSet *msgMessageInsertedObjects = [ZMOperationLoop objectSetFromObjectIDs:messageInsertObjectsIds inContext:self.syncStrategy.msgMOC];
            NSSet *msgMessageUpdatedObjects = [ZMOperationLoop objectSetFromObjectIDs:messageUpdateObjectsIds inContext:self.syncStrategy.msgMOC];
            [self.syncStrategy processSaveWithMessageInsertedObjects:msgMessageInsertedObjects updateObjects:msgMessageUpdatedObjects];
            [ZMRequestAvailableNotification msgNotifyNewRequestsAvailable:self];
        }];
    }
   
    NSMutableSet *muUIInsertObject = [NSMutableSet setWithSet:uiInsertedObjects];
    [muUIInsertObject minusSet: messageInsertObjects];
    NSMutableSet *muUIUpdateObject = [NSMutableSet setWithSet:uiUpdatedObjects];
    [muUIUpdateObject minusSet: messageUpdateObjects];
    NSSet *remainInsertObjectsIDs = [ZMOperationLoop objectIDsetFromObject: muUIInsertObject];
    NSSet *remainUpdateObjectsIDs = [ZMOperationLoop objectIDsetFromObject: muUIUpdateObject];

    if (remainInsertObjectsIDs.count == 0 && remainUpdateObjectsIDs.count == 0) {
        return;
    }
    [self.syncMOC performGroupedBlock:^{
        ZM_STRONG(self);
        NSSet *syncInsertedObjects = [ZMOperationLoop objectSetFromObjectIDs:remainInsertObjectsIDs inContext:self.syncStrategy.syncMOC];
        NSSet *syncUpdatedObjects = [ZMOperationLoop objectSetFromObjectIDs:remainUpdateObjectsIDs inContext:self.syncStrategy.syncMOC];
        [self.syncStrategy processSaveWithInsertedObjects:syncInsertedObjects updateObjects:syncUpdatedObjects];
        [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
    }];
    
    
}

- (void)syncContextDidSave:(NSNotification *)note
{
    //
    // N.B.: We don't need to do any context / queue switching here, since we're on the sync context's queue.
    //
    
    NSSet *syncInsertedObjects = note.userInfo[NSInsertedObjectsKey];
    NSSet *syncUpdatedObjects = note.userInfo[NSUpdatedObjectsKey];
    
    if (syncInsertedObjects.count == 0 && syncUpdatedObjects.count == 0) {
        return;
    }
    
    [self.syncStrategy processSaveWithInsertedObjects:syncInsertedObjects updateObjects:syncUpdatedObjects];
    [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
}

- (void)msgContextDidSave:(NSNotification *)note
{
    //
    // N.B.: We don't need to do any context / queue switching here, since we're on the sync context's queue.
    //
    
    NSSet *msgInsertedObjects = note.userInfo[NSInsertedObjectsKey];
    NSSet *msgUpdatedObjects = note.userInfo[NSUpdatedObjectsKey];
    
    if (msgInsertedObjects.count == 0 && msgUpdatedObjects.count == 0) {
        return;
    }
    
    [self.syncStrategy processSaveWithMessageInsertedObjects:msgInsertedObjects updateObjects:msgUpdatedObjects];
    [ZMRequestAvailableNotification msgNotifyNewRequestsAvailable:self];
}

- (ZMTransportRequestGenerator)requestGenerator {
    
    ZM_WEAK(self);
    return ^ZMTransportRequest *(void) {
        ZM_STRONG(self);
        if (self == nil) {
            return nil;
        }
        ZMTransportRequest *request = [self.syncStrategy nextRequest];
        [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.syncMOC block:^(ZMTransportResponse *response) {
            ZM_STRONG(self);
            
            [self.syncStrategy.syncMOC enqueueDelayedSaveWithGroup:response.dispatchGroup];
            
            // Check if there is something to do now and when the save completes
            [ZMRequestAvailableNotification notifyNewRequestsAvailable:self];
        }]];
        
        return request;
    };
    
}

- (ZMTransportRequestGenerator)msgRequestGenerator {
    ZM_WEAK(self);
    return ^ZMTransportRequest *(void) {
        ZM_STRONG(self);
        if (self == nil) {
            return nil;
        }
        ZMTransportRequest *request = [self.syncStrategy messagNextRequest];
        [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.msgMOC block:^(ZMTransportResponse *response) {
            ZM_STRONG(self);
            [self.syncStrategy.msgMOC enqueueDelayedSaveWithGroup:response.dispatchGroup];
            // Check if there is something to do now and when the save completes
            [ZMRequestAvailableNotification msgNotifyNewRequestsAvailable:self];
        }]];
        
        return request;
    };
    
}

- (void)executeNextOperation
{    
    if (self.shouldStopEnqueueing) {
        return;
    }
    
    // this generates the request
    ZMTransportRequestGenerator generator = [self requestGenerator];
    
    BackgroundActivity *enqueueActivity = [BackgroundActivityFactory.sharedFactory startBackgroundActivityWithName:@"executeNextOperation"];

    if (!enqueueActivity) {
        return;
    }

    ZM_WEAK(self);
    [self.syncMOC performGroupedBlock:^{
        ZM_STRONG(self);
        BOOL enqueueMore = YES;
        while (self && enqueueMore && !self.shouldStopEnqueueing) {
            ZMTransportEnqueueResult *result = [self.transportSession attemptToEnqueueSyncRequestWithGenerator:generator];
            enqueueMore = result.didGenerateNonNullRequest && result.didHaveLessRequestThanMax;
        }
        [BackgroundActivityFactory.sharedFactory endBackgroundActivity:enqueueActivity];
    }];
}

- (void)executeMsgNextOperation
{
    if (self.shouldStopEnqueueing) {
        return;
    }
    
    // this generates the request
    ZMTransportRequestGenerator generator = [self msgRequestGenerator];
    
    BackgroundActivity *enqueueActivity = [BackgroundActivityFactory.sharedFactory startBackgroundActivityWithName:@"executeNextOperation"];

    if (!enqueueActivity) {
        return;
    }

    ZM_WEAK(self);
    [self.msgMOC performGroupedBlock:^{
        ZM_STRONG(self);
        BOOL enqueueMore = YES;
        while (self && enqueueMore && !self.shouldStopEnqueueing) {
            ZMTransportEnqueueResult *result = [self.transportSession attemptToEnqueueSyncRequestWithGenerator:generator];
            enqueueMore = result.didGenerateNonNullRequest && result.didHaveLessRequestThanMax;
        }
        [BackgroundActivityFactory.sharedFactory endBackgroundActivity:enqueueActivity];
    }];
}

- (PushNotificationStatus *)pushNotificationStatus
{
    return self.applicationStatusDirectory.pushNotificationStatus;
}

- (PushHugeNotificationStatus *)pushHugeNotificationStatus
{
    return self.applicationStatusDirectory.pushHugeNotificationStatus;
}

- (CallEventStatus *)callEventStatus {
    return self.applicationStatusDirectory.callEventStatus;
}

@end


@implementation ZMOperationLoop (NewRequests)

- (void)newRequestsAvailable
{
    [self executeNextOperation];
}

- (void)newMsgRequestsAvailable {
    [self executeMsgNextOperation];
}

- (void)newExtensionSingleRequestsAvailable {}


- (void)newExtensionStreamRequestsAvailable {}



@end
