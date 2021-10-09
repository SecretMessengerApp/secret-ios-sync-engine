//

import XCTest
@testable import WireSyncEngine

class ConversationTests_LegalHold: ConversationTestsBase {

    func testThatItInsertsLegalHoldSystemMessage_WhenDiscoveringLegalHoldClientOnSending() {
        // given
        XCTAssertTrue(login())
        let conversation = self.conversation(for: selfToUser1Conversation)
        mockTransportSession.performRemoteChanges { (session) in
            session.registerClient(for: self.user1, label: "Legal Hold", type: "legalhold", deviceClass: "legalhold")
        }
        
        // when
        userSession?.performChanges {
            conversation?.append(text: "Hello")
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let secondToLastMessage = conversation?.lastMessages()[1] as? ZMSystemMessage
        XCTAssertEqual(secondToLastMessage?.systemMessageType, .legalHoldEnabled)
        XCTAssertEqual(conversation?.legalHoldStatus, .pendingApproval)
    }
    
    func testThatItInsertsLegalHoldSystemMessage_WhenLegalHoldClientIsReportedAsDeletedOnSending() {
        // given
        XCTAssertTrue(login())
        let conversation = self.conversation(for: selfToUser1Conversation)
        var legalHoldClient: MockUserClient!
        mockTransportSession.performRemoteChanges { (session) in
            legalHoldClient = session.registerClient(for: self.user1, label: "Legal Hold", type: "legalhold", deviceClass: "legalhold")
        }
        
        userSession?.performChanges {
            conversation?.append(text: "Hello")
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(conversation?.legalHoldStatus, .pendingApproval)
        
        conversation?.acknowledgePrivacyWarning(withResendIntent: true)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(conversation?.legalHoldStatus, .enabled)
        
        mockTransportSession.performRemoteChanges { (session) in
            session.deleteUserClient(withIdentifier: legalHoldClient.identifier!, for: self.user1)
        }
        
        // when
        userSession?.performChanges {
            conversation?.append(text: "Hello")
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        let lastMessage = conversation?.lastMessage as? ZMSystemMessage
        XCTAssertEqual(lastMessage?.systemMessageType, .legalHoldDisabled)
        XCTAssertEqual(conversation?.legalHoldStatus, .disabled)
    }
    
    func testThatItInsertsLegalHoldSystemMessage_WhenUserUnderLegalHoldIsJoiningConversation() {
        // given
        XCTAssertTrue(login())
        
        let legalHoldUser = self.user(for: user1)!
        let groupConversation = self.conversation(for: self.groupConversation)
        mockTransportSession.performRemoteChanges { (session) in
            session.registerClient(for: self.user1, label: "Legal Hold", type: "legalhold", deviceClass: "legalhold")
        }
        legalHoldUser.fetchUserClients()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        groupConversation?.addParticipants(Set(arrayLiteral: legalHoldUser), userSession: userSession!, completion: { _ in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let lastMessage = groupConversation?.lastMessage as? ZMSystemMessage
        XCTAssertEqual(lastMessage?.systemMessageType, .legalHoldEnabled)
        XCTAssertEqual(groupConversation?.legalHoldStatus, .pendingApproval)
    }
    
    func testThatItInsertsLegalHoldSystemMessage_WhenUserUnderLegalHoldIsLeavingConversation() {
        // given
        XCTAssertTrue(login())
        
        let legalHoldUser = self.user(for: user1)!
        let groupConversation = self.conversation(for: self.groupConversation)
        
        mockTransportSession.performRemoteChanges { (session) in
            session.registerClient(for: self.user1, label: "Legal Hold", type: "legalhold", deviceClass: "legalhold")
        }
        legalHoldUser.fetchUserClients()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        groupConversation?.addParticipants(Set(arrayLiteral: legalHoldUser), userSession: userSession!, completion: { _ in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(groupConversation?.legalHoldStatus, .pendingApproval)
        
        // when
        groupConversation?.removeParticipant(legalHoldUser, userSession: userSession!, completion: {_ in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let lastMessage = groupConversation?.lastMessage as? ZMSystemMessage
        XCTAssertEqual(lastMessage?.systemMessageType, .legalHoldDisabled)
        XCTAssertEqual(groupConversation?.legalHoldStatus, .disabled)
    }
    
    // MARK: Legal hold status flag
    
    func testThatItUpdatesLegalHoldStatus_WhenReceivingLegalHoldStatusFlagEnabled() {
        // given
        XCTAssertTrue(login())
        
        let selfUserClient = self.selfUser.clients.anyObject() as! MockUserClient
        let otherUserClient = user1.clients.anyObject() as! MockUserClient
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        mockTransportSession.performRemoteChanges { (session) in
            session.registerClient(for: self.user1, label: "Legal Hold", type: "legalhold", deviceClass: "legalhold")
        }
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello")).setLegalHoldStatus(.ENABLED)
            self.selfToUser1Conversation.encryptAndInsertData(from: otherUserClient, to: selfUserClient, data: genericMessage!.data()!)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversation?.legalHoldStatus, .pendingApproval)
    }
    
    func testThatItUpdatesLegalHoldStatus_WhenReceivingLegalHoldStatusFlagDisabled() {
        // given
        XCTAssertTrue(login())
        
        let legalHoldUser = self.user(for: user1)!
        let selfUserClient = self.selfUser.clients.anyObject() as! MockUserClient
        let otherUserClient = user1.clients.anyObject() as! MockUserClient
        var legalHoldClient: MockUserClient!
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        mockTransportSession.performRemoteChanges { (session) in
            legalHoldClient = session.registerClient(for: self.user1, label: "Legal Hold", type: "legalhold", deviceClass: "legalhold")
        }
        
        legalHoldUser.fetchUserClients()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(conversation?.legalHoldStatus, .pendingApproval)
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            session.deleteUserClient(withIdentifier: legalHoldClient.identifier!, for: self.user1)
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello")).setLegalHoldStatus(.DISABLED)
            self.selfToUser1Conversation.encryptAndInsertData(from: otherUserClient, to: selfUserClient, data: genericMessage!.data()!)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversation?.legalHoldStatus, .disabled)
    }
    
    func testThatItRepairsAnIncorrectLegalHoldStatus_AfterReceivingLegalHoldStatusFlagEnabled() {
        // given
        XCTAssertTrue(login())
        
        let selfUserClient = self.selfUser.clients.anyObject() as! MockUserClient
        let otherUserClient = user1.clients.anyObject() as! MockUserClient
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello")).setLegalHoldStatus(.ENABLED)
            self.selfToUser1Conversation.encryptAndInsertData(from: otherUserClient, to: selfUserClient, data: genericMessage!.data()!)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
         // then
        XCTAssertEqual(conversation?.legalHoldStatus, .disabled)
    }
    
    func testThatItRepairsAnIncorrectLegalHoldStatus_AfterReceivingLegalHoldStatusFlagDisabled() {
        // given
        XCTAssertTrue(login())
        
        let selfUserClient = self.selfUser.clients.anyObject() as! MockUserClient
        let otherUserClient = user1.clients.anyObject() as! MockUserClient
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        mockTransportSession.performRemoteChanges { (session) in
            session.registerClient(for: self.user1, label: "Legal Hold", type: "legalhold", deviceClass: "legalhold")
        }

        userSession?.performChanges {
            conversation!.append(text: "This is the best group!")
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(conversation?.legalHoldStatus, .pendingApproval)

        // when
        mockTransportSession.performRemoteChanges { (session) in
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello")).setLegalHoldStatus(.DISABLED)
            self.selfToUser1Conversation.encryptAndInsertData(from: otherUserClient, to: selfUserClient, data: genericMessage!.data()!)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversation?.legalHoldStatus, .pendingApproval)
    }
    
}
