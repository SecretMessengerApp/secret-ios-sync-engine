//

import WireDataModel

extension ConversationListChangeInfo {
    @objc(addObserver:forList:userSession:)
    public static func add(observer: ZMConversationListObserver,
                           for list: ZMConversationList,
                           userSession: ZMUserSession
        ) -> NSObjectProtocol {
        return self.addListObserver(observer, for: list, managedObjectContext: userSession.managedObjectContext)
    }
    
    @objc(addConversationListReloadObserver:userSession:)
    public static func add(observer: ZMConversationListReloadObserver, userSession: ZMUserSession) -> NSObjectProtocol {
        return addReloadObserver(observer, managedObjectContext: userSession.managedObjectContext)
    }
}

