

import Foundation
import CallKit

enum ConversationLookupError: Error {
    case accountDoesNotExist
    case conversationDoesNotExist
}

extension SessionManager: CallKitManagerDelegate {
    
    func lookupConversation(by handle: CallHandle, completionHandler: @escaping (Result<ZMConversation>) -> Void) {
        guard let account  = accountManager.account(with: handle.accountId) else {
            return completionHandler(.failure(ConversationLookupError.accountDoesNotExist))
        }
        
        withSession(for: account) { (userSession) in
            guard let conversation = ZMConversation(remoteID: handle.conversationId, createIfNeeded: false, in: userSession.managedObjectContext) else {
                return completionHandler(.failure(ConversationLookupError.conversationDoesNotExist))
            }
            
            completionHandler(.success(conversation))
        }
    }
    
    func endAllCalls() {
        for userSession in backgroundUserSessions.values {
            userSession.callCenter?.endAllCalls()
        }
    }
    
}
