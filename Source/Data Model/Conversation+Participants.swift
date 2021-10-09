//

import Foundation
 
 private let zmLog = ZMSLog(tag: "Conversation")
 
 public enum ConversationRemoveParticipantError: Error {
    case unknown, invalidOperation, conversationNotFound
    
    init?(response: ZMTransportResponse) {
        switch (response.httpStatus, response.payloadLabel()) {
        case (403, "invalid-op"?): self = .invalidOperation
        case (404, "no-conversation"?): self = .conversationNotFound
        case (400..<499, _): self = .unknown
        default: return nil
        }
    }
 }
 
 public enum ConversationAddParticipantsError: Error {
    case unknown, invalidOperation, accessDenied, notConnectedToUser, conversationNotFound, tooManyMembers
    
    init?(response: ZMTransportResponse) {
        switch (response.httpStatus, response.payloadLabel()) {
        case (403, "invalid-op"?): self = .invalidOperation
        case (403, "access-denied"?): self = .accessDenied
        case (403, "not-connected"?): self = .notConnectedToUser
        case (404, "no-conversation"?): self = .conversationNotFound
        case (403, "too-many-members"?): self = .tooManyMembers
        case (400..<499, _): self = .unknown
        default: return nil
        }
    }
 }

extension ZMConversation {
    
    public func addParticipants(_ participants: Set<ZMUser>, userSession: ZMUserSession, completion: @escaping (VoidResult) -> Void) {
        
        guard [.group, .hugeGroup].contains(conversationType),
              !participants.isEmpty,
              !participants.contains(ZMUser.selfUser(inUserSession: userSession))
        else { return completion(.failure(ConversationAddParticipantsError.invalidOperation)) }
        
        let request = ConversationParticipantRequestFactory.requestForAddingParticipants(participants, conversation: self)
        
        request.add(ZMCompletionHandler(on: managedObjectContext!) { response in
            if response.httpStatus == 200 {
                if let payload = response.payload, let event = ZMUpdateEvent(fromEventStreamPayload: payload, uuid: nil) {
                    userSession.syncManagedObjectContext.performGroupedBlock {
                        userSession.operationLoop.syncStrategy.process(updateEvents: [event], ignoreBuffer: false)
                    }
                }
                
                completion(.success)
            }
            else if response.httpStatus == 204 {
                completion(.success) // users were already added to the conversation
            }
            else {
                let error = ConversationAddParticipantsError(response: response) ?? .unknown
                zmLog.debug("Error adding participants: \(error)")
                completion(.failure(error))
            }
        })
        
        userSession.transportSession.enqueueOneTime(request)
    }
    
    public func removeParticipant(_ participant: ZMUser, userSession: ZMUserSession, completion: @escaping (VoidResult) -> Void) {
        
        guard [.group, .hugeGroup].contains(conversationType), let conversationId = remoteIdentifier  else { return completion(.failure(ConversationRemoveParticipantError.invalidOperation)) }
        
        let isRemovingSelfUser = participant.isSelfUser
        let request = ConversationParticipantRequestFactory.requestForRemovingParticipant(participant, conversation: self)
        
        request.add(ZMCompletionHandler(on: managedObjectContext!) { response in
            if response.httpStatus == 200 {
                if let payload = response.payload, let event = ZMUpdateEvent(fromEventStreamPayload: payload, uuid: nil) {
                    userSession.syncManagedObjectContext.performGroupedBlock {
                        let conversation = ZMConversation(remoteID: conversationId, createIfNeeded: false, in: userSession.syncManagedObjectContext)
                        
                        // Update cleared timestamp if self user left and deleted history
                        if let clearedTimestamp = conversation?.clearedTimeStamp, clearedTimestamp == conversation?.lastServerTimeStamp, isRemovingSelfUser {
                            conversation?.updateCleared(fromPostPayloadEvent: event)
                        }
                        
                        userSession.operationLoop.syncStrategy.process(updateEvents: [event], ignoreBuffer: false)
                    }
                }
                
                completion(.success)
            }
            else if response.httpStatus == 204 {
                completion(.success) // user was already not part of conversation
            }
            else {
                let error = ConversationRemoveParticipantError(response: response) ?? .unknown
                zmLog.debug("Error removing participant: \(error)")
                completion(.failure(error))
            }
        })
        
        userSession.transportSession.enqueueOneTime(request)
    }
    
}

internal struct ConversationParticipantRequestFactory {
    
    static func requestForRemovingParticipant(_ participant: ZMUser, conversation: ZMConversation) -> ZMTransportRequest {
        
        let participantKind = participant.isServiceUser ? "bots" : "members"
        let path = "/conversations/\(conversation.remoteIdentifier!.transportString())/\(participantKind)/\(participant.remoteIdentifier!.transportString())"
        
        return ZMTransportRequest(path: path, method: .methodDELETE, payload: nil)
    }
    
    static func requestForAddingParticipants(_ participants: Set<ZMUser>, conversation: ZMConversation) -> ZMTransportRequest {
        
        let path = "/conversations/\(conversation.remoteIdentifier!.transportString())/members"
        let payload = [
            "users": participants.compactMap { $0.remoteIdentifier?.transportString() }
        ]
        
        return ZMTransportRequest(path: path, method: .methodPOST, payload: payload as ZMTransportData)
    }
    
    
}
