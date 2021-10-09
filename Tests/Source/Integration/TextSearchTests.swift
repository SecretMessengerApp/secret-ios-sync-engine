//


import XCTest
import WireTesting


fileprivate class MockSearchDelegate: TextSearchQueryDelegate {
    var results = [TextQueryResult]()

    func textSearchQueryDidReceive(result: TextQueryResult) {
        results.append(result)
    }
}


class TextSearchTests: ConversationTestsBase {
        
    func testThatItFindsAMessageSendRemotely() {
        // Given
        XCTAssertTrue(login())

        let firstClient = user1.clients.anyObject() as! MockUserClient
        let selfClient = selfUser.clients.anyObject() as! MockUserClient

        // When
        mockTransportSession.performRemoteChanges { session in
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello there!"))
            self.selfToUser1Conversation.encryptAndInsertData(from: firstClient, to: selfClient, data: genericMessage.data())
        }

        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        guard let convo = conversation(for: selfToUser1Conversation) else { return XCTFail("Undable to get conversation") }
        let lastMessage = convo.lastMessage
        XCTAssertEqual(lastMessage?.textMessageData?.messageText, "Hello there!")

        // Then
        verifyThatItCanSearch(for: "There", in: convo, andFinds: lastMessage)
    }

    func testThatItFindsAMessageEditedRemotely() {
        // Given
        XCTAssertTrue(login())

        let firstClient = user1.clients.anyObject() as! MockUserClient
        let selfClient = selfUser.clients.anyObject() as! MockUserClient
        let nonce = UUID.create()

        // When
        mockTransportSession.performRemoteChanges { _ in
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello there!"), nonce: nonce)
            self.selfToUser1Conversation.encryptAndInsertData(from: firstClient, to: selfClient, data: genericMessage.data())
        }

        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        guard let convo = conversation(for: selfToUser1Conversation) else { return XCTFail("Undable to get conversation") }
        guard let lastMessage = convo.lastMessage else { return XCTFail("Undable to get message") }
        XCTAssertEqual(lastMessage.textMessageData?.messageText, "Hello there!")

        // And when
        mockTransportSession.performRemoteChanges { _ in
            let genericMessage = ZMGenericMessage.message(content: ZMMessageEdit.edit(with: ZMText.text(with: "This is an edit!!"), replacingMessageId: nonce))
            self.selfToUser1Conversation.encryptAndInsertData(from: firstClient, to: selfClient, data: genericMessage.data())
        }

        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        guard let editedMessage = convo.lastMessage else { return XCTFail("Undable to get message") }
        XCTAssertEqual(editedMessage.textMessageData?.messageText, "This is an edit!!")

        // Then
        verifyThatItCanSearch(for: "edit", in: convo, andFinds: editedMessage)
        verifyThatItCanSearch(for: "Hello", in: convo, andFinds: nil)
    }

    func testThatItDoesFindAnEphemeralMessageSentRemotely() {
        // Given
        XCTAssertTrue(login())

        let firstClient = user1.clients.anyObject() as! MockUserClient
        let selfClient = selfUser.clients.anyObject() as! MockUserClient
        let text = "This is an ephemeral message"

        // When
        mockTransportSession.performRemoteChanges { session in
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: text), expiresAfter: 300)
            self.selfToUser1Conversation.encryptAndInsertData(from: firstClient, to: selfClient, data: genericMessage.data())
        }

        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        guard let convo = conversation(for: selfToUser1Conversation) else { return XCTFail("Undable to get conversation") }
        let lastMessage = convo.lastMessage
        XCTAssertEqual(lastMessage?.textMessageData?.messageText, text)

        // Then
        verifyThatItCanSearch(for: "ephemeral", in: convo, andFinds: lastMessage)
    }

    func testThatItDoesNotFindAMessageDeletedRemotely() {
        // Given
        XCTAssertTrue(login())

        let firstClient = user1.clients.anyObject() as! MockUserClient
        let selfClient = selfUser.clients.anyObject() as! MockUserClient
        let nonce = UUID.create()

        // When
        mockTransportSession.performRemoteChanges { session in
            let genericMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello there!"), nonce: nonce)
            self.selfToUser1Conversation.encryptAndInsertData(from: firstClient, to: selfClient, data: genericMessage.data())
        }

        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        guard let convo = conversation(for: selfToUser1Conversation) else { return XCTFail("Undable to get conversation") }
        let lastMessage = convo.lastMessage
        XCTAssertEqual(lastMessage?.textMessageData?.messageText, "Hello there!")

        // Then
        verifyThatItCanSearch(for: "Hello", in: convo, andFinds: lastMessage)

        // And when
        mockTransportSession.performRemoteChanges { _ in
            let genericMessage = ZMGenericMessage.message(content: ZMMessageDelete(messageID: nonce))
            self.selfToUser1Conversation.encryptAndInsertData(from: firstClient, to: selfClient, data: genericMessage.data())
        }

        // Then
        verifyThatItCanSearch(for: "Hello", in: convo, andFinds: nil)
    }

    func verifyThatItCanSearch(for query: String, in conversation: ZMConversation, andFinds message: ZMMessage?, file: StaticString = #file, line: UInt = #line) {
        // Given
        let delegate = MockSearchDelegate()
        let searchQuery = TextSearchQuery(conversation: conversation, query: query, delegate: delegate)

        // When
        searchQuery?.execute()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5), file: file, line: line)

        // Then
        guard let result = delegate.results.last else { return XCTFail("No search result found", file: file, line: line) }

        if let message = message {
            XCTAssertEqual(result.matches.count, 1, file: file, line: line)
            guard let match = result.matches.first else { return XCTFail("No match found", file: file, line: line) }
            XCTAssertEqual(match.textMessageData?.messageText, message.textMessageData?.messageText, file: file, line: line)
        } else {
            XCTAssert(result.matches.isEmpty, file: file, line: line)
        }
    }

}
