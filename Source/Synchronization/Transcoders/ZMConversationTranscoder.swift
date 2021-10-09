////

import Foundation

private let log = ZMSLog(tag: "ConversationTranscoder")

extension ZMConversationTranscoder {
    @objc(createGroupOrSelfConversationFromTransportData:serverTimeStamp:source:)
    public func createGroupOrSelfConversation(from transportData: NSDictionary,
                                       serverTimeStamp: Date!,
                                       source: ZMConversationSource) -> ZMConversation? {
        guard let convRemoteID = transportData.uuid(forKey: "id") else {
            log.error("Missing ID in conversation payload")
            return nil
        }

        var conversationCreated: ObjCBool = false

        guard let conversation = ZMConversation(remoteID: convRemoteID, createIfNeeded:
            true, in: managedObjectContext, created: &conversationCreated) else { return nil }

        conversation.update(withTransportData: transportData as? [AnyHashable : Any], serverTimeStamp: serverTimeStamp)

        if conversation.conversationType != ZMConversationType.`self` && conversationCreated.boolValue == true {

            if serverTimeStamp == nil {
                log.error("serverTimeStamp is nil!")
            }

            // we just got a new conversation, we display new conversation header
            conversation.appendNewConversationSystemMessage(at: serverTimeStamp,
                users: conversation.activeParticipants)

            if source == .slowSync {
                // Slow synced conversations should be considered read from the start
                conversation.lastReadServerTimeStamp = conversation.lastModifiedDate
            }
        }

        return conversation
    }

    @objc (processAccessModeUpdateEvent:inConversation:)
    public func processAccessModeUpdate(event: ZMUpdateEvent, in conversation: ZMConversation) {
        precondition(event.type == .conversationAccessModeUpdate, "invalid update event type")
        guard let payload = event.payload["data"] as? [String : AnyHashable] else { return }
        guard let access = payload["access"] as? [String] else { return }
        guard let accessRole = payload["access_role"] as? String else { return }

        conversation.accessMode = ConversationAccessMode(values: access)
        conversation.accessRole = ConversationAccessRole(rawValue: accessRole)
    }
    
    @objc (processDestructionTimerUpdateEvent:inConversation:)
    public func processDestructionTimerUpdate(event: ZMUpdateEvent, in conversation: ZMConversation?) {
        precondition(event.type == .conversationMessageTimerUpdate, "invalid update event type")
        guard let payload = event.payload["data"] as? [String : AnyHashable],
            let senderUUID = event.senderUUID(),
            let user = ZMUser(remoteID: senderUUID, createIfNeeded: false, in: managedObjectContext) else { return }
        
        var timeout: MessageDestructionTimeout?
        let timeoutIntegerValue = (payload["message_timer"] as? Int64) ?? 0
        
        // Backend is sending the miliseconds, we need to convert to seconds.
        timeout = .synced(MessageDestructionTimeoutValue(rawValue: TimeInterval(timeoutIntegerValue / 1000)))
        
        let fromSelf = user.isSelfUser
        let fromOffToOff = !(conversation?.hasSyncedDestructionTimeout ?? false) && timeout == .synced(.none)
        
        let noChange = fromOffToOff || conversation?.messageDestructionTimeout == timeout
        
        // We seem to get duplicate update events for timeout changes, returning
        // early will avoid duplicate system messages.
        if fromSelf && noChange { return }

        conversation?.messageDestructionTimeout = timeout
        
        if let timestamp = event.timeStamp(), let conversation = conversation {
            // system message should reflect the synced timer value, not local
            let timer = conversation.hasSyncedDestructionTimeout ? conversation.messageDestructionTimeoutValue : 0
            let message = conversation.appendMessageTimerUpdateMessage(fromUser: user, timer: timer, timestamp: timestamp)
            localNotificationDispatcher?.process(message)
        }
    }
    
    @objc (processReceiptModeUpdate:inConversation:lastServerTimestamp:)
    public func processReceiptModeUpdate(event: ZMUpdateEvent, in conversation: ZMConversation, lastServerTimestamp: Date) {
        precondition(event.type == .conversationReceiptModeUpdate, "invalid update event type")
        
        guard let payload = event.payload["data"] as? [String : AnyHashable],
              let readReceiptMode = payload["receipt_mode"] as? Int,
              let serverTimestamp = event.timeStamp(),
              let senderUUID = event.senderUUID(),
              let sender = ZMUser(remoteID: senderUUID, createIfNeeded: false, in: managedObjectContext)
        else { return }
        
        // Discard event if it has already been applied
        guard serverTimestamp.compare(lastServerTimestamp) == .orderedDescending else { return }
        
        let newValue = readReceiptMode > 0
        conversation.hasReadReceiptsEnabled = newValue
        conversation.appendMessageReceiptModeChangedMessage(fromUser: sender, timestamp: serverTimestamp, enabled: newValue)
    }
}

extension ZMConversation {
    @objc public var accessPayload: [String]? {
        return accessMode?.stringValue
    }
    
    @objc public var accessRolePayload: String? {
        return accessRole?.rawValue
    }
    
    @objc
    public func requestForUpdatingSelfInfo() -> ZMUpstreamRequest? {
        guard let remoteIdentifier = self.remoteIdentifier else {
            return nil
        }
        
        var payload: [String: Any] = [:]
        var updatedKeys: Set<String> = Set()
        
        if hasLocalModifications(forKey: ZMConversationSilencedChangedTimeStampKey) {
            if silencedChangedTimestamp == nil {
                silencedChangedTimestamp = Date()
            }
            
            payload[ZMConversationInfoOTRMutedValueKey] = mutedMessageTypes != .none
            payload[ZMConversationInfoOTRMutedStatusValueKey] = mutedMessageTypes.rawValue
            payload[ZMConversationInfoOTRMutedReferenceKey] = silencedChangedTimestamp?.transportString()
            
            updatedKeys.insert(ZMConversationSilencedChangedTimeStampKey)
        }
        
        if hasLocalModifications(forKey: ZMConversationIsPlacedTopKey) {
            payload[ZMConversationInfoPlaceTopKey] = isPlacedTop
            updatedKeys.insert(ZMConversationIsPlacedTopKey)
        }
        
        if hasLocalModifications(forKey: ZMConversationArchivedChangedTimeStampKey) {
            if archivedChangedTimestamp == nil {
                archivedChangedTimestamp = Date()
            }
            
            payload[ZMConversationInfoOTRArchivedValueKey] = isArchived
            payload[ZMConversationInfoOTRArchivedReferenceKey] = archivedChangedTimestamp?.transportString()
            
            updatedKeys.insert(ZMConversationArchivedChangedTimeStampKey)
        }
        
        guard !updatedKeys.isEmpty else {
            return nil
        }
        
        let path = NSString.path(withComponents: [ConversationsPath, remoteIdentifier.transportString(), "self"])
        let request = ZMTransportRequest(path: path, method: .methodPUT, payload: payload as NSDictionary)
        return ZMUpstreamRequest(keys: updatedKeys, transportRequest: request)
    }
}
