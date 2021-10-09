//

import Foundation

public enum ConversationDeletionError: Error {
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

extension ZMConversation {
    
    /// Delete a conversation remotely and locally for everyone
    ///
    /// Only team conversations can be deleted.
    public func delete(in userSession: ZMUserSession, completion: @escaping (VoidResult) -> Void) {
        
        guard ZMUser.selfUser(inUserSession: userSession).canDeleteConversation(self),
              let conversationId = remoteIdentifier,
              let request = ConversationDeletionRequestFactory.requestForDeletingTeamConversation(self)
        else {
            return completion(.failure(ConversationDeletionError.invalidOperation))
        }
        
        request.add(ZMCompletionHandler(on: managedObjectContext!) { response in
            if response.httpStatus == 200 {
                
                userSession.syncManagedObjectContext.performGroupedBlock {
                    guard let conversation = ZMConversation(remoteID: conversationId, createIfNeeded: false, in: userSession.syncManagedObjectContext) else { return }
                    userSession.syncManagedObjectContext.delete(conversation)
                    userSession.syncManagedObjectContext.saveOrRollback()
                }
                
                completion(.success)
            } else {
                let error = ConversationDeletionError(response: response) ?? .unknown
                Logging.network.debug("Error deleting converation: \(error)")
                completion(.failure(error))
            }
        })
        
        userSession.transportSession.enqueueOneTime(request)
        
    }
    
}

struct ConversationDeletionRequestFactory {
    
    static func requestForDeletingTeamConversation(_ conversation: ZMConversation) -> ZMTransportRequest? {
        guard let conversationId = conversation.remoteIdentifier, let teamRemoteIdentifier = conversation.teamRemoteIdentifier else { return nil }
        
        let path = "/teams/\(teamRemoteIdentifier.transportString())/conversations/\(conversationId.transportString())"
        
        return ZMTransportRequest(path: path, method: .methodDELETE, payload: nil)
    }
    
}
