//


import Foundation
import WireSyncEngine

extension ZMUserSession {
    @discardableResult func insertUnreadDotGeneratingMessageMessage(in conversation: ZMConversation) -> ZMSystemMessage {
        let newTime = conversation.lastServerTimeStamp?.addingTimeInterval(5) ?? Date()
        
        let message = ZMSystemMessage(nonce: UUID(), managedObjectContext: self.managedObjectContext)
        message.serverTimestamp = newTime
        message.systemMessageType = .missedCall
        conversation.lastServerTimeStamp = message.serverTimestamp
        conversation.mutableMessages.add(message)
        return message
    }
    
    @discardableResult func insertConversationWithUnreadMessage() -> ZMConversation {
        let conversation = ZMConversation.insertGroupConversation(intoUserSession: self, withParticipants: [], name: nil, in: nil)
        conversation.remoteIdentifier = UUID()
        
        self.insertUnreadDotGeneratingMessageMessage(in: conversation)
        // then
        XCTAssertNotNil(conversation.firstUnreadMessage)
        return conversation
    }
}

class ZMUserSessionSwiftTests: ZMUserSessionTestsBase {
  
    
    func testThatItMarksTheConversationsAsRead() throws {
        // given
        let conversationsRange: CountableClosedRange = 1...10
        
        let conversations: [ZMConversation] = conversationsRange.map { _ in
            return self.sut.insertConversationWithUnreadMessage()
        }

        try self.uiMOC.save()
        
        // when
        self.sut.markAllConversationsAsRead()
        
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertEqual(conversations.filter { $0.firstUnreadMessage != nil }.count, 0)
    }
}
