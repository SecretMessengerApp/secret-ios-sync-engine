////

import Foundation

class ConversationMessageTimerTests: IntegrationTest {
    
    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
        createExtraUsersAndConversations()
        createTeamAndConversations()
    }
    
    private func responsePayload(for conversation: ZMConversation, timeout: MessageDestructionTimeoutValue) -> ZMTransportData {
        var payload: [String: Any] = [
            "from": user1.identifier,
            "conversation": conversation.remoteIdentifier!.transportString(),
            "time": NSDate().transportString(),
            "type": "conversation.message-timer-update"
        ]
        
        switch timeout {
        case .none: payload["data"] = ["message_timer": NSNull()]
        default: payload["data"] = ["message_timer": Int(timeout.rawValue)]
        }
        
        return payload as ZMTransportData
    }

    func testThatItUpdatesTheDestructionTimerOneDay() {
        // given
        XCTAssert(login())
        let sut = conversation(for: groupConversation)!
        XCTAssertNil(sut.messageDestructionTimeout)
        
        // when
        setGlobalTimeout(for: sut, timeout: 86400000)
        
        // then
        XCTAssertEqual(sut.messageDestructionTimeout, .synced(.oneDay))
    }

    func testThatItRemovesTheDestructionTimer() {
        // given
        XCTAssert(login())
        let sut = conversation(for: groupConversation)!
        
        // given
        userSession?.enqueueChanges {
            sut.messageDestructionTimeout = .synced(.oneDay)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        XCTAssertNotNil(sut.messageDestructionTimeout)
        
        setGlobalTimeout(for: sut, timeout: .none)

        // then
        guard let request = mockTransportSession.receivedRequests().first else {
            XCTFail()
            return
        }
        XCTAssertNotNil(request.payload?.asDictionary()?["message_timer"] as? NSNull)
        XCTAssertNil(sut.messageDestructionTimeout)
    }
    
    func testThatItCanSetASyncedTimerWithExistingLocalOneAndFallsBackToTheLocalAfterRemovingSyncedTimer() {
        // given
        XCTAssert(login())
        let sut = conversation(for: groupConversation)!

        userSession?.enqueueChanges {
            sut.messageDestructionTimeout = .local(.oneDay)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        XCTAssertEqual(sut.messageDestructionTimeout, .local(86400))
        
        // when
        setGlobalTimeout(for: sut, timeout: 10000)
        
        // then
        XCTAssertEqual(sut.messageDestructionTimeout, .synced(10))
        
        // when
        setGlobalTimeout(for: sut, timeout: 0)
        
        // then
        XCTAssertEqual(sut.messageDestructionTimeout, .local(86400))
    }
    
    // MARK: - Helper
    
    private func setGlobalTimeout(
        for conversation: ZMConversation,
        timeout: MessageDestructionTimeoutValue,
        file: StaticString = #file,
        line: UInt = #line
        ) {
        mockTransportSession.resetReceivedRequests()
        let identifier = conversation.remoteIdentifier!.transportString()
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(identifier)/message-timer" else { return nil }
            return ZMTransportResponse(payload: self.responsePayload(for: conversation, timeout: timeout), httpStatus: 200, transportSessionError: nil)
        }
        
        // when
        conversation.setMessageDestructionTimeout(timeout, in: userSession!) { result in
            switch result {
            case .success: break
            case .failure(let error): XCTFail("failed to update timeout \(error)", file: file, line: line)
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1), file: file, line: line)
        
        // then
        XCTAssertEqual(mockTransportSession.receivedRequests().count, 1, "wrong request count", file: file, line: line)
        guard let request = mockTransportSession.receivedRequests().first else { return }
        XCTAssertEqual(request.path, "/conversations/\(identifier)/message-timer", "wrong path \(request.path)", file: file, line: line)
        XCTAssertEqual(request.method, .methodPUT, "wrong method", file: file, line: line)
    }
}
