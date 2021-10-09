//

import Foundation
import WireUtilities

extension ZMSyncStrategy: ZMUpdateEventConsumer {
    

    @objc(processUpdateEvents:ignoreBuffer:)
    public func process(updateEvents: [ZMUpdateEvent], ignoreBuffer: Bool) {
        if ignoreBuffer || isReadyToProcessEvents {
            consume(updateEvents: updateEvents)
        } else {
            Logging.eventProcessing.info("Buffering \(updateEvents.count) event(s)")
            updateEvents.forEach(eventsBuffer.addUpdateEvent)
        }
    }
    
    @objc(consumeUpdateEvents:)
    public func consume(updateEvents: [ZMUpdateEvent]) {
        eventDecoder.processEvents(updateEvents) { [weak self] (decryptedUpdateEvents) in
            guard let `self` = self else { return }
            
            let date = Date()
            let fetchRequest = prefetchRequest(updateEvents: decryptedUpdateEvents)
            let prefetchResult = syncMOC.executeFetchRequestBatchOrAssert(fetchRequest)
            
            Logging.eventProcessing.info("ConsumeUpdateEvents Consuming: [\n\(decryptedUpdateEvents.map({ "\tevent: \(ZMUpdateEvent.eventTypeString(for: $0.type) ?? "Unknown")" }).joined(separator: "\n"))\n]")
        
            for event in decryptedUpdateEvents {
                if event.senderClientID() == ZMUser.selfUser(in: moc).selfClient()?.remoteIdentifier {
                    continue
                }
                let date1 = Date()
                for eventConsumer in self.eventConsumers {
                    eventConsumer.processEvents([event], liveEvents: true, prefetchResult: prefetchResult)
                }
                let time = -date1.timeIntervalSinceNow
                
                if time > 0.001 {
                    Logging.eventProcessing.debug("Event processed in \(time): \(event.type.stringValue ?? ""))")
                }
                self.eventProcessingTracker?.registerEventProcessed()
                let time1 = -date1.timeIntervalSinceNow
               
                if time1 > 0.001 {
                    Logging.eventProcessing.debug("Event processed and registerEvent in \(time): \(event.type.stringValue ?? ""))")
                }
            }
            
            Logging.eventProcessing.debug("\(decryptedUpdateEvents.count) Events processed and registerEvent in \(-date.timeIntervalSinceNow)")
            
            let date1 = Date()
            localNotificationDispatcher?.processEvents(decryptedUpdateEvents, liveEvents: true, prefetchResult: nil)
            Logging.eventProcessing.debug("localNotificationDispatcher?.processEvents in \(-date1.timeIntervalSinceNow)")
            
            let date2 = Date()
            if let messages = fetchRequest.noncesToFetch as? Set<UUID>,
                messages.count > 0,
                let conversations = fetchRequest.remoteIdentifiersToFetch as? Set<UUID> {
                let confirmationMessages = ZMConversation.confirmDeliveredMessages(messages, in: conversations, with: syncMOC)
                for message in confirmationMessages {
                    self.applicationStatusDirectory?.deliveryConfirmation.needsToConfirmMessage(message.nonce!)
                }
                Logging.eventProcessing.debug("ConfirmMessage:\(confirmationMessages.count) in \(-date2.timeIntervalSinceNow)")
            }
            
            syncMOC.saveOrRollback()
            Logging.eventProcessing.debug("syncMOC.saveOrRollback()")
            
            Logging.eventProcessing.debug("\(decryptedUpdateEvents.count) Events processed in \(-date.timeIntervalSinceNow): \(self.eventProcessingTracker?.debugDescription ?? "")")
            let time = -date.timeIntervalSinceNow
           
            if time > 10 {
                Logging.eventProcessing.debug("\(decryptedUpdateEvents.count) Events processed over 10 in \(time)")
            }
            
        }
        
    }
    
    @objc(prefetchRequestForUpdateEvents:)
    public func prefetchRequest(updateEvents: [ZMUpdateEvent]) -> ZMFetchRequestBatch {
        var messageNounces: Set<UUID> = Set()
        var conversationNounces: Set<UUID> = Set()
        
     
        for eventConsumer in eventConsumers {
            if let messageNoncesToPrefetch = eventConsumer.messageNoncesToPrefetch?(toProcessEvents: updateEvents)  {
                messageNounces.formUnion(messageNoncesToPrefetch)
            }
            
            if let conversationRemoteIdentifiersToPrefetch = eventConsumer.conversationRemoteIdentifiersToPrefetch?(toProcessEvents: updateEvents) {
                conversationNounces.formUnion(conversationRemoteIdentifiersToPrefetch)
            }
        }
        
        let fetchRequest = ZMFetchRequestBatch()
        fetchRequest.addNonces(toPrefetchMessages: messageNounces)
        fetchRequest.addConversationRemoteIdentifiers(toPrefetchConversations: conversationNounces)
        
        return fetchRequest
    }
    
    @objc(prefetchHugeRequestForUpdateEvents:)
    public func prefetchHugeRequest(updateEvents: [ZMUpdateEvent]) -> ZMFetchRequestBatch {
        var conversationNounces: Set<UUID> = Set()
        
        for eventConsumer in eventConsumers {
            if let conversationRemoteIdentifiersToPrefetch = eventConsumer.conversationRemoteIdentifiersToPrefetch?(toProcessEvents: updateEvents) {
                conversationNounces.formUnion(conversationRemoteIdentifiersToPrefetch)
            }
        }
        
        let fetchRequest = ZMFetchRequestBatch()
        fetchRequest.addConversationRemoteIdentifiers(toPrefetchConversations: conversationNounces)
        return fetchRequest
    }
    

}

