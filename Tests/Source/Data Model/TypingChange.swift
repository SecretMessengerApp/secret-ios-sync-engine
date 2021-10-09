//

import Foundation

@objcMembers
public class TypingChange : NSObject {
    
    let conversation : ZMConversation
    let typingUsers : Set<ZMUser>
    
    init (conversation : ZMConversation, typingUsers : Set<ZMUser>) {
        self.conversation = conversation
        self.typingUsers = typingUsers
    }
}
