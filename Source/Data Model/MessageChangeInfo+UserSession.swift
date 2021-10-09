//

import WireDataModel

extension MessageChangeInfo {
    
    /// Adds a ZMMessageObserver to the specified message
    /// To observe messages and their users (senders, systemMessage users), observe the conversation window instead
    /// Messages observed with this call will not contain information about user changes
    /// You must hold on to the token and use it to unregister
    @objc(addObserver:forMessage:userSession:)
    public static func add(observer: ZMMessageObserver,
                           for message: ZMConversationMessage,
                           userSession: ZMUserSession) -> NSObjectProtocol {
        return self.add(observer: observer, for: message, managedObjectContext: userSession.managedObjectContext)
    }
}

extension NewUnreadMessagesChangeInfo {
    
    /// Adds a ZMNewUnreadMessagesObserver
    /// You must hold on to the token and use it to unregister
    @objc(addNewMessageObserver:forUserSession:)
    public static func add(observer: ZMNewUnreadMessagesObserver, for userSession: ZMUserSession) -> NSObjectProtocol {
        return self.add(observer: observer, managedObjectContext: userSession.managedObjectContext)
    }

}

extension NewUnreadKnockMessagesChangeInfo {
    /// Adds a ZMNewUnreadKnocksObserver
    /// You must hold on to the token and use it to unregister
    @objc(addNewKnockObserver:forUserSession:)
    public static func add(observer: ZMNewUnreadKnocksObserver, for userSession: ZMUserSession) -> NSObjectProtocol {
        return self.add(observer: observer, managedObjectContext: userSession.managedObjectContext)
    }
    
}
