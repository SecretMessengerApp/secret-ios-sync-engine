//

import Foundation

public protocol OpenConversationObserver {
    func didOpen(conversation: ZMConversation)
    func didClose(conversation: ZMConversation)
}

extension ZMUserSession: OpenConversationObserver {
    @objc public func didOpen(conversation: ZMConversation) {
        self.userExpirationObserver.check(usersIn: conversation)
    }
    
    @objc public func didClose(conversation: ZMConversation) {
        // no-op
    }
}
