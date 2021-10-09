//


import XCTest
import WireTesting

class DeleteMessagesTests: ConversationTestsBase {

    func testThatItCreatesARequestToSendADeletedMessageAndDeletesItLocallencrypty() {
        // given
        XCTAssertTrue(login())
        var message: ZMConversationMessage! = nil
        
        userSession?.performChanges {
            guard let conversation = self.conversation(for: self.selfToUser1Conversation) else {return XCTFail()}
            message = conversation.append(text: "Hello")
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertNotNil(message)

        // when
        mockTransportSession.resetReceivedRequests()
        userSession?.performChanges {
            ZMMessage.deleteForEveryone(message)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        let requests = mockTransportSession.receivedRequests()
        XCTAssertEqual(requests.count, 1)
        guard let request = requests.first else { return XCTFail() }
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(selfToUser1Conversation.identifier)/otr/messages")
        XCTAssertTrue(message.hasBeenDeleted)
    }

    func testThatItDeletesAMessageIfItIsDeletedRemotelyByTheSender() {
        // given
        XCTAssertTrue(login())
        
        let fromClient = user1.clients.anyObject() as! MockUserClient
        let toClient = selfUser.clients.anyObject() as! MockUserClient
        let textMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello"))
        
        // when
        mockTransportSession.performRemoteChanges { session in
            self.selfToUser1Conversation.encryptAndInsertData(from: fromClient, to: toClient, data: textMessage.data())
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let conversation = self.conversation(for: selfToUser1Conversation) else {return XCTFail()}
        XCTAssertEqual(conversation.allMessages.count, 2) // system message & inserted message

        guard let message = conversation.lastMessage as? ZMClientMessage , message.textMessageData?.messageText == "Hello" else { return XCTFail() }
        let genericMessage = ZMGenericMessage.message(content: ZMMessageDelete(messageID: message.nonce!))
        
        // when
        mockTransportSession.performRemoteChanges { session in
            self.selfToUser1Conversation.encryptAndInsertData(from: fromClient, to: toClient, data: genericMessage.data())
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(message.hasBeenDeleted)
        XCTAssertEqual(conversation.allMessages.count, 2) // 2x system message
        XCTAssertNotEqual(conversation.lastMessages().last as? ZMClientMessage, message)
        guard let systemMessage = conversation.lastMessage as? ZMSystemMessage else { return XCTFail() }
        XCTAssertEqual(systemMessage.systemMessageType, ZMSystemMessageType.messageDeletedForEveryone)
    }
    
    func testThatItDoesNotDeleteAMessageIfItIsDeletedRemotelyBySomeoneElse() {
        // given
        XCTAssertTrue(login())
        
        let firstClient = user1.clients.anyObject() as! MockUserClient
        let secondClient = user2.clients.anyObject() as! MockUserClient
        let selfClient = selfUser.clients.anyObject() as! MockUserClient
        let textMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello"))
        
        // when
        mockTransportSession.performRemoteChanges { session in
            self.groupConversation.encryptAndInsertData(from: firstClient, to: selfClient, data: textMessage.data())
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let conversation = self.conversation(for: self.groupConversation) else {return XCTFail()}
        XCTAssertEqual(conversation.allMessages.count, 3) // 2x system message & inserted message
        guard let message = conversation.lastMessage, message.textMessageData?.messageText == "Hello" else { return XCTFail() }
        
        let genericMessage = ZMGenericMessage.message(content: ZMMessageDelete(messageID: message.nonce!))
        
        // when
        mockTransportSession.performRemoteChanges { session in
            self.groupConversation.encryptAndInsertData(from: secondClient, to: selfClient, data: genericMessage.data())
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(message.hasBeenDeleted)
        XCTAssertEqual(conversation.allMessages.count, 3) // 2x system message & inserted message
        XCTAssertEqual(conversation.lastMessage, message)
    }

    func testThatItRetriesToSendADeletedMessageIfItCouldNotBeSentBefore() {
        // given
        XCTAssertTrue(login())
        var message: ZMConversationMessage! = nil
        
        userSession?.performChanges {
            guard let conversation = self.conversation(for: self.selfToUser1Conversation) else {return XCTFail()}
            message = conversation.append(text: "Hello")
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertNotNil(message)
        
        // when
        mockTransportSession.resetReceivedRequests()
        var requestCount = 0
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(self.selfToUser1Conversation.identifier)/otr/messages" else { return nil }
            if requestCount < 4 {
                requestCount += 1
                return ZMTransportResponse(transportSessionError: NSError.tryAgainLaterError() as Error)
            }
            
            return nil
        }
        
        userSession?.performChanges {
            ZMMessage.deleteForEveryone(message)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        let requests = mockTransportSession.receivedRequests()
        XCTAssertEqual(requests.count, 5)
        XCTAssertEqual(requestCount, 4)
        guard let request = requests.last else { return XCTFail() }
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(selfToUser1Conversation.identifier)/otr/messages")
        XCTAssertTrue(message.hasBeenDeleted)
    }
    
    func testThatItNotifiesTheObserverIfAMessageGetsDeletedRemotely() {
        // given
        XCTAssertTrue(login())
        
        let fromClient = user1.clients.anyObject() as! MockUserClient
        let toClient = selfUser.clients.anyObject() as! MockUserClient
        let textMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello"))
        
        // when
        mockTransportSession.performRemoteChanges { session in
            self.selfToUser1Conversation.encryptAndInsertData(from: fromClient, to: toClient, data: textMessage.data())
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        guard let conversation = self.conversation(for: selfToUser1Conversation) else {return XCTFail()}
        
        // then
        XCTAssertEqual(conversation.allMessages.count, 2) // system message & inserted message

        guard let message = conversation.lastMessage as? ZMClientMessage , message.textMessageData?.messageText == "Hello" else { return XCTFail() }
        let genericMessage = ZMGenericMessage.message(content: ZMMessageDelete(messageID: message.nonce!))
        
        // when
        mockTransportSession.performRemoteChanges { session in
            self.selfToUser1Conversation.encryptAndInsertData(from: fromClient, to: toClient, data: genericMessage.data())
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(message.hasBeenDeleted)
        XCTAssertEqual(conversation.allMessages.count, 2) // 2x system message
    }

}
