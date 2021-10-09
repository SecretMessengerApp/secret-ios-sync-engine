//

import XCTest

class ConversationTests_Participants: ConversationTestsBase {
    
    func testThatAddingAndRemovingAParticipantToAConversationSendsOutChangeNotifications() {
        
        // given
        XCTAssert(login())
        
        let conversation = self.conversation(for: emptyGroupConversation)!
        let connectedUser = user(for: self.user2)!
        
        let observer = ConversationChangeObserver(conversation: conversation)
        observer?.clearNotifications()
        
        // when
        conversation.addParticipants(Set(arrayLiteral: connectedUser), userSession: userSession!, completion: { (_) in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then - Participants changes and messages changes (System message for the added user)
        
        XCTAssertEqual(observer?.notifications.count, 1)
        let note1 = observer?.notifications.firstObject as! ConversationChangeInfo
        XCTAssertEqual(note1.conversation, conversation)
        XCTAssertTrue(note1.participantsChanged)
        XCTAssertTrue(note1.messagesChanged)
        observer?.notifications.removeAllObjects()
        
        // when
        conversation.removeParticipant(connectedUser, userSession: userSession!, completion: { (_) in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then - Participants changes and messages changes (System message for the removed user)
        XCTAssertEqual(observer?.notifications.count, 1)
        let note2 = observer?.notifications.firstObject as! ConversationChangeInfo
        XCTAssertEqual(note2.conversation, conversation)
        XCTAssertTrue(note2.participantsChanged)
        XCTAssertTrue(note2.messagesChanged)
        
        observer?.notifications.removeAllObjects()
    }
        
    func testThatAddingParticipantsToAConversationIsSynchronizedWithBackend() {
        // given
        XCTAssert(login())
        
        let conversation = self.conversation(for: emptyGroupConversation)!
        let connectedUser = user(for: self.user2)!
        
        XCTAssertFalse(conversation.activeParticipants.contains(connectedUser))
        
        // when
        conversation.addParticipants(Set(arrayLiteral: connectedUser), userSession: userSession!, completion: { (_) in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(conversation.activeParticipants.contains(connectedUser))
        
        // Tear down & recreate contexts
        recreateSessionManagerAndDeleteLocalData()
        XCTAssertTrue(login())
        
        // then
        XCTAssertTrue(self.conversation(for: emptyGroupConversation)!.activeParticipants.contains(user(for: self.user2)!))
    }
    
    func testThatRemovingParticipantsFromAConversationIsSynchronizedWithBackend() {
        // given
        XCTAssert(login())
        
        let conversation = self.conversation(for: groupConversation)!
        let connectedUser = user(for: self.user2)!
        
        XCTAssertTrue(conversation.activeParticipants.contains(connectedUser))
        
        // when
        conversation.removeParticipant(connectedUser, userSession: userSession!, completion: { (_) in })
        XCTAssertTrue( waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(conversation.activeParticipants.contains(connectedUser))
        
        // Tear down & recreate contexts
        recreateSessionManagerAndDeleteLocalData()
        XCTAssertTrue(login())
        
        // then
        XCTAssertFalse(self.conversation(for: groupConversation)!.activeParticipants.contains(user(for: self.user2)!))
    }
    
}
