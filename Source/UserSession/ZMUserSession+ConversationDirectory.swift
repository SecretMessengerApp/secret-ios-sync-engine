//

import Foundation

extension ZMUserSession {
    
    public var conversationDirectory: ConversationDirectoryType {
        if managedObjectContext == nil {
            if self.storeProvider == nil {
                fatal("storeProvider==nil")
            }
            if self.storeProvider.contextDirectory == nil {
                fatal("contextDirectory==nil")
            }
            fatal("managedObjectContext==nil")
        }
        return managedObjectContext.conversationListDirectory()
    }
    
}
