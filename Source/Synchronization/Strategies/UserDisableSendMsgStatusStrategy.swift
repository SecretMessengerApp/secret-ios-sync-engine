

import Foundation
import WireSystem
import WireTransport
import WireUtilities
import WireCryptobox
import WireDataModel


@objcMembers
public final class UserDisableSendMsgStatusStrategy: ZMObjectSyncStrategy, ZMObjectStrategy, ZMUpstreamTranscoder {
    
    fileprivate(set) var modifiedSync: ZMUpstreamModifiedObjectSync! = nil
    fileprivate(set) var insertSync: ZMUpstreamInsertedObjectSync! = nil
    public var requestsFactory: UserDisableSendMsgRequestFactory! = nil
    public weak var dispatcher: LocalNotificationDispatcher?
    
    fileprivate var didRetryRegisteringSignalingKeys : Bool = false
    
    fileprivate var insertSyncFilter: NSPredicate {
        return NSPredicate { object, _ -> Bool in
            guard let o = object as? UserDisableSendMsgStatus, o.needUpload else { return false }
            return true
        }
    }
    
    fileprivate var modifySyncFilter: NSPredicate {
        return NSPredicate { object, _ -> Bool in
            guard let o = object as? UserDisableSendMsgStatus, !o.needUpload, o.modifiedKeys?.contains(ZMConversationInfoBlockTimeKey) ?? false else { return false }
            return true
        }
    }
    
    public init(context: NSManagedObjectContext, dispatcher: LocalNotificationDispatcher? = nil)
    {
        super.init(managedObjectContext: context)
        self.dispatcher = dispatcher
        let modifiedPredicate = self.modifiedPredicate()
        requestsFactory = UserDisableSendMsgRequestFactory()
        self.modifiedSync = ZMUpstreamModifiedObjectSync(transcoder: self, entityName: UserDisableSendMsgStatus.entityName(), update: modifiedPredicate, filter: modifySyncFilter, keysToSync: [ZMConversationInfoBlockTimeKey], managedObjectContext: context)
        self.insertSync = ZMUpstreamInsertedObjectSync(transcoder: self, entityName: UserDisableSendMsgStatus.entityName(), filter: insertSyncFilter, managedObjectContext: context)
    }
    
    func modifiedPredicate() -> NSPredicate {
        guard let baseModifiedPredicate = UserDisableSendMsgStatus.predicateForObjectsThatNeedToBeUpdatedUpstream() else {
            return NSPredicate(value: false)
        }
        return baseModifiedPredicate
    }
    
    public func nextRequest() -> ZMTransportRequest? {
        
        if let request = insertSync.nextRequest() {
            return request
        }
        
        if let request = modifiedSync.nextRequest() {
            return request
        }
        
        return nil
    }
    
    //we don;t use this method but it's required by ZMObjectStrategy protocol
    public var requestGenerators: [ZMRequestGenerator] {
        return []
    }
    
    public var contextChangeTrackers: [ZMContextChangeTracker] {
        return [self.insertSync, self.modifiedSync]
    }
    
    public func shouldProcessUpdatesBeforeInserts() -> Bool {
        return false
    }
    
    
    public func request(forUpdating managedObject: ZMManagedObject, forKeys keys: Set<String>) -> ZMUpstreamRequest? {
        if let managedObject = managedObject as? UserDisableSendMsgStatus {
            var request: ZMUpstreamRequest!
            switch keys {
            case _ where keys.contains(ZMConversationInfoBlockTimeKey):
                request = requestsFactory.updateUserDisableSendMsgRequest(status: managedObject)
            default: fatal("")
            }
            
            return request
        }
        else {
            fatal("Called requestForUpdatingObject() on \(managedObject) to sync keys: \(keys)")
        }
    }
    
    public func shouldCreateRequest(toSyncObject managedObject: ZMManagedObject, forKeys keys: Set<String>, withSync sync: Any) -> Bool {
        if let status = managedObject as? UserDisableSendMsgStatus {
            if  sync is ZMUpstreamInsertedObjectSync, status.needUpload  {
                return true
            }
            if  sync is ZMUpstreamModifiedObjectSync, !status.needUpload && keys.contains(ZMConversationInfoBlockTimeKey), !self.insertSync.hasCurrentlyRunningRequests {
                return true
            }
        }
        return false
    }
    
    public func request(forInserting managedObject: ZMManagedObject, forKeys keys: Set<String>?) -> ZMUpstreamRequest? {
        if let status = managedObject as? UserDisableSendMsgStatus, status.needUpload {
            return requestsFactory.updateUserDisableSendMsgRequest(status: managedObject)
        }
        return nil
    }
    
    public func shouldRetryToSyncAfterFailed(toUpdate managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse, keysToParse: Set<String>) -> Bool {
        if keysToParse.contains(ZMConversationInfoBlockTimeKey) {
            if response.httpStatus == 400, let label = response.payloadLabel(), label == "bad-request" {
                return true
            }
        }
        return false
    }
    
    public func updateInsertedObject(_ managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse) {
        if let status = managedObject as? UserDisableSendMsgStatus {
            status.needUpload = false
        }
        else {
            fatal("Called updateInsertedObject() on \(managedObject.description)")
        }
    }
    
    /// Returns whether synchronization of this object needs additional requests
    public func updateUpdatedObject(_ managedObject: ZMManagedObject, requestUserInfo: [AnyHashable: Any]?, response: ZMTransportResponse, keysToParse: Set<String>) -> Bool {
        guard let status = managedObject as? UserDisableSendMsgStatus, keysToParse.contains(ZMConversationInfoBlockTimeKey) else {return false}
        status.resetLocallyModifiedKeys([])
        return false
    }
    
    public func fetchRequestForTrackedObjects() -> NSFetchRequest<NSFetchRequestResult>? {
        let request = UserDisableSendMsgStatus.sortedFetchRequest()
        return request
    }
    
    // Should return the objects that need to be refetched from the BE in case of upload error
    public func objectToRefetchForFailedUpdate(of managedObject: ZMManagedObject) -> ZMManagedObject? {
        return nil
    }
    
    public func processEvents(_ events: [ZMUpdateEvent], liveEvents: Bool, prefetchResult: ZMFetchRequestBatchResult?) {
        events.forEach(processUpdateEvent)
    }
    
    fileprivate func processUpdateEvent(_ event: ZMUpdateEvent) {
        
        if (event.type == .conversationUpdateBlockTime) {
            guard let dataPayload = event.payload["data"] as? [String: Any], let block = dataPayload[ZMConversationInfoBlockTimeKey] as? Int64,
                let duration = dataPayload[ZMConversationInfoBlockDurationKey] as? Int64,
                let cnv = event.payload["conversation"] as? String,
                let context = self.managedObjectContext,
                let userid = dataPayload["block_user"] as? String,
                let uuid = UUID(uuidString: cnv),
                let conversation = ZMConversation.init(remoteID: uuid, createIfNeeded: false, in: context) else {return}
            if(dataPayload.keys.contains(ZMConversationInfoBlockTimeKey) && dataPayload.keys.contains(ZMConversationInfoBlockDurationKey)) {
                UserDisableSendMsgStatus.update(managedObjectContext: context, block_time: NSNumber(value: block), block_duration: NSNumber(value: duration), user: userid, conversation: cnv, fromPushChannel: true)
                self.appendSystemMessage(event: event, inConversation: conversation)
            }
        }
    }
    
    func appendSystemMessage(event: ZMUpdateEvent, inConversation:ZMConversation) {
        guard let context = self.managedObjectContext else {return}
        guard let systemMessage = ZMSystemMessage.createOrUpdate(from: event, in: context) else {return}
        self.dispatcher?.process(systemMessage)
    }
    
}


public final class UserDisableSendMsgRequestFactory {
    
    public func updateUserDisableSendMsgRequest(status: ZMManagedObject) -> ZMUpstreamRequest? {
        if let status = status as? UserDisableSendMsgStatus  {
            let payload = [ZMConversationInfoBlockTimeKey: status.block_time, ZMConversationInfoBlockDurationKey: status.block_duration]
            guard let cnv = status.withConversation?.remoteIdentifier?.transportString(),
                let uid = status.userid else {return nil}
            let request = ZMTransportRequest(path: "/conversations/\(cnv)/block/\(uid)", method: ZMTransportRequestMethod.methodPUT, payload: payload as ZMTransportData)
            
            return ZMUpstreamRequest(keys: Set(arrayLiteral: ZMConversationInfoBlockTimeKey), transportRequest: request, userInfo: nil)
        }
        return nil
    }
    
}
