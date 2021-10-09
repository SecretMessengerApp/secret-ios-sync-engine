//

import Foundation
import WireDataModel
import CoreData

@objc(ZMCallStateObserver)
public final class CallStateObserver : NSObject {
    
    @objc static public let CallInProgressNotification = Notification.Name(rawValue: "ZMCallInProgressNotification")
    @objc static public let CallInProgressKey = "callInProgress"
    
    fileprivate weak var notificationStyleProvider: CallNotificationStyleProvider?
    fileprivate let localNotificationDispatcher : LocalNotificationDispatcher
    fileprivate let uiContext : NSManagedObjectContext
    fileprivate let syncContext : NSManagedObjectContext
    fileprivate var callStateToken : Any? = nil
    fileprivate var missedCalltoken : Any? = nil
    fileprivate let systemMessageGenerator = CallSystemMessageGenerator()
    
    @objc public init(localNotificationDispatcher: LocalNotificationDispatcher,
                      contextProvider: ZMManagedObjectContextProvider,
                      callNotificationStyleProvider: CallNotificationStyleProvider) {
        
        self.uiContext = contextProvider.managedObjectContext
        self.syncContext = contextProvider.syncManagedObjectContext
        self.notificationStyleProvider = callNotificationStyleProvider
        self.localNotificationDispatcher = localNotificationDispatcher
        
        super.init()
        
        self.callStateToken = WireCallCenterV3.addCallStateObserver(observer: self, context: uiContext)
        self.missedCalltoken = WireCallCenterV3.addMissedCallObserver(observer: self, context: uiContext)
    }
    
    fileprivate var callInProgress : Bool = false {
        didSet {
            if callInProgress != oldValue {
                syncContext.performGroupedBlock {
                    NotificationInContext(name: CallStateObserver.CallInProgressNotification,
                                          context: self.syncContext.notificationContext,
                                          userInfo: [ CallStateObserver.CallInProgressKey : self.callInProgress ]).post()
                }
            }
        }
    }
    
}

extension CallStateObserver : WireCallCenterCallStateObserver, WireCallCenterMissedCallObserver  {
    
    public func callCenterDidChange(callState: CallState, conversation: ZMConversation, caller: UserType, timestamp: Date?, previousCallState: CallState?) {
        let callerId = (caller as? ZMUser)?.remoteIdentifier
        let conversationId = conversation.remoteIdentifier
        
        syncContext.performGroupedBlock {
            guard
                let callerId = callerId,
                let conversationId = conversationId,
                let conversation = ZMConversation(remoteID: conversationId, createIfNeeded: false, in: self.syncContext),
                let caller = ZMUser(remoteID: callerId, createIfNeeded: false, in: self.syncContext)
            else {
                return
            }
            
            self.uiContext.performGroupedBlock {
                if let activeCallCount = self.uiContext.zm_callCenter?.activeCalls.count {
                    self.callInProgress = activeCallCount > 0
                }
            }
            
            // This will unarchive the conversation when there is an incoming call
            self.updateConversation(conversation, with: callState, timestamp: timestamp)
            
            // CallKit depends on a fetched conversation & and is not used for muted conversations
            let skipCallKit = conversation.needsToBeUpdatedFromBackend || conversation.mutedMessageTypesIncludingAvailability != .none
            let notificationStyle = self.notificationStyleProvider?.callNotificationStyle ?? .callKit
            
            if notificationStyle == .pushNotifications || skipCallKit {
                self.localNotificationDispatcher.process(callState: callState, in: conversation, caller: caller)
            }
            
            self.updateConversationListIndicator(convObjectID: conversation.objectID, callState: callState)
            
            if let systemMessage = self.systemMessageGenerator.appendSystemMessageIfNeeded(callState: callState, conversation: conversation, caller: caller, timestamp: timestamp, previousCallState: previousCallState) {
                switch (systemMessage.systemMessageType, callState, conversation.conversationType) {
                case (.missedCall, .terminating(reason: .canceled), _ ):
                    // the caller canceled the call
                    fallthrough
                case (.missedCall, .terminating(reason: .normal), .group):
                    // group calls we didn't join, end with reason .normal. We should still insert a missed call in this case.
                    // since the systemMessageGenerator keeps track whether we joined or not, we can use it to decide whether we should show a missed call APNS
                    self.localNotificationDispatcher.processMissedCall(in: conversation, caller: caller)
                default:
                    break
                }
                
                self.syncContext.enqueueDelayedSave()
            }
        }
    }
    
    public func updateConversationListIndicator(convObjectID: NSManagedObjectID, callState: CallState){
        // We need to switch to the uiContext here because we are making changes that need to be present on the UI when the change notification fires
        uiContext.performGroupedBlock {
            guard let uiConv = (try? self.uiContext.existingObject(with: convObjectID)) as? ZMConversation else { return }
            
            switch callState {
            case .incoming(video: _, shouldRing: let shouldRing, degraded: _):
                uiConv.isIgnoringCall = uiConv.mutedMessageTypesIncludingAvailability != .none || !shouldRing
                uiConv.isCallDeviceActive = false
            case .terminating, .none, .mediaStopped:
                uiConv.isCallDeviceActive = false
                uiConv.isIgnoringCall = false
            case .outgoing, .answered, .established:
                uiConv.isCallDeviceActive = true
            case .unknown, .establishedDataChannel:
                break
            }
            
            if self.uiContext.zm_hasChanges {
                NotificationDispatcher.notifyNonCoreDataChanges(objectID: convObjectID,
                                                                changedKeys: [ZMConversationListIndicatorKey],
                                                                uiContext: self.uiContext)
            }
        }
    }
    
    public func callCenterMissedCall(conversation: ZMConversation, caller: UserType, timestamp: Date, video: Bool) {
        let callerId = (caller as? ZMUser)?.remoteIdentifier
        let conversationId = conversation.remoteIdentifier
        
        syncContext.performGroupedBlock {
            guard
                let callerId = callerId,
                let conversationId = conversationId,
                let conversation = ZMConversation(remoteID: conversationId, createIfNeeded: false, in: self.syncContext),
                let caller = ZMUser(remoteID: callerId, createIfNeeded: false, in: self.syncContext)
                else {
                    return
            }
            
            if (self.notificationStyleProvider?.callNotificationStyle ?? .callKit) == .pushNotifications {
                self.localNotificationDispatcher.processMissedCall(in: conversation, caller: caller)
            }
            
            conversation.appendMissedCallMessage(fromUser: caller, at: timestamp)
            self.syncContext.enqueueDelayedSave()
        }
    }
    
    private func updateConversation(_ conversation: ZMConversation, with callState: CallState, timestamp: Date?) {
        switch callState {
        case .incoming(_, shouldRing: true, degraded: _):
            if conversation.isArchived && conversation.mutedMessageTypes != .all {
                conversation.isArchived = false
            }
            
            if let timestamp = timestamp {
                conversation.updateLastModified(timestamp)
            }
            
            syncContext.enqueueDelayedSave()
        default: break
        }
    }

}
