//

import XCTest

@testable import WireSyncEngine

class Conversation_ParticipantsTests: MessagingTest {
    
    func responsePayloadForUserEventInConversation(_ conversationId: UUID, senderId: UUID, usersIds: [UUID], eventType: String, time: Date = Date()) -> ZMTransportData {
        return ["conversation": conversationId.transportString(),
                "data": usersIds.map({ $0.transportString() }),
                "from": senderId.transportString(),
                "time": time.transportString(),
                "type": eventType] as ZMTransportData
    }
    
    // MARK: - Adding participants
    
    func testThatItParsesAllKnownAddParticipantErrorResponses() {
        
        let errorResponses: [(ConversationAddParticipantsError, ZMTransportResponse)] = [
            (ConversationAddParticipantsError.invalidOperation, ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)),
            (ConversationAddParticipantsError.accessDenied, ZMTransportResponse(payload: ["label": "access-denied"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)),
            (ConversationAddParticipantsError.notConnectedToUser, ZMTransportResponse(payload: ["label": "not-connected"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)),
            (ConversationAddParticipantsError.conversationNotFound, ZMTransportResponse(payload: ["label": "no-conversation"] as ZMTransportData, httpStatus: 404, transportSessionError: nil))
        ]
        
        for (expectedError, response) in errorResponses {
            guard let error = ConversationAddParticipantsError(response: response) else { return XCTFail() }
            
            if case error = expectedError {
                // success
            } else {
                XCTFail()
            }
        }
    }
    
    func testThatAddingParticipantsForwardEventInResponseToEventConsumers() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members" else { return nil }
            
            let payload = self.responsePayloadForUserEventInConversation(conversation.remoteIdentifier!, senderId: UUID(), usersIds: [user.remoteIdentifier!], eventType: EventConversationMemberJoin)
            return ZMTransportResponse(payload: payload, httpStatus: 200, transportSessionError: nil)
        }
        
        let receivedSuccess = expectation(description: "received success")
        
        // when
        conversation.addParticipants(Set(arrayLiteral: user), userSession: mockUserSession) { result in
            switch result {
            case .success:
                receivedSuccess.fulfill()
            default: break
            }
        }
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(processedUpdateEvents.count, 1);
        XCTAssertEqual((processedUpdateEvents.firstObject as? ZMUpdateEvent)?.type, ZMUpdateEventType.conversationMemberJoin)
        
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatAddingParticipantsFailWhenAddingSelfUser() {
        
        // given
        let selfUser = ZMUser.selfUser(in: uiMOC)
        selfUser.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        
        let receivedError = expectation(description: "received error")
        
        // when
        conversation.addParticipants(Set(arrayLiteral: selfUser), userSession: mockUserSession) { result in
            switch result {
            case .failure(let error):
                if case ConversationAddParticipantsError.invalidOperation = error {
                    receivedError.fulfill()
                }
            default: break
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatAddingParticipantsFailForConversationTypesButGroups() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        for conversationType in [ZMConversationType.connection, ZMConversationType.oneOnOne, ZMConversationType.`self`, ZMConversationType.invalid] {
            let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
            conversation.remoteIdentifier = UUID()
            conversation.conversationType = conversationType
            
            let receivedError = expectation(description: "received error")
            
            // when
            conversation.addParticipants(Set(arrayLiteral: user), userSession: mockUserSession) { result in
                switch result {
                case .failure(let error):
                    if case ConversationAddParticipantsError.invalidOperation = error {
                        receivedError.fulfill()
                    }
                default: break
                }
            }
            
            XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        }
    }
    
    func testThatAddParticipantsFailOnInvalidOperation() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members" else { return nil }
            
            return ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
        }
        
        let receivedError = expectation(description: "received error")
        
        // when
        conversation.addParticipants(Set(arrayLiteral: user), userSession: mockUserSession) { result in
            switch result {
            case .failure(let error):
                if case ConversationAddParticipantsError.invalidOperation = error {
                    receivedError.fulfill()
                }
            default: break
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatAddParticipantsFailOnConversationNotFound() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members" else { return nil }
            
            return ZMTransportResponse(payload: ["label": "no-conversation"] as ZMTransportData, httpStatus: 404, transportSessionError: nil)
        }
        
        let receivedError = expectation(description: "received error")
        
        // when
        conversation.addParticipants(Set(arrayLiteral: user), userSession: mockUserSession) { result in
            switch result {
            case .failure(let error):
                if case ConversationAddParticipantsError.conversationNotFound = error {
                    receivedError.fulfill()
                }
            default: break
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    // MARK: - Removing participant
    
    func testThatItParsesAllKnownRemoveParticipantErrorResponses() {
        
        let errorResponses: [(ConversationRemoveParticipantError, ZMTransportResponse)] = [
            (ConversationRemoveParticipantError.invalidOperation, ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)),
            (ConversationRemoveParticipantError.conversationNotFound, ZMTransportResponse(payload: ["label": "no-conversation"] as ZMTransportData, httpStatus: 404, transportSessionError: nil))
        ]
        
        for (expectedError, response) in errorResponses {
            guard let error = ConversationRemoveParticipantError(response: response) else { return XCTFail() }
            
            if case error = expectedError {
                // success
            } else {
                XCTFail()
            }
        }
    }
    
    func testThatRemoveParticipantSucceedsOnNoChange() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members/\(user.remoteIdentifier!.transportString())" else { return nil }
            
            return ZMTransportResponse(payload: nil, httpStatus: 204, transportSessionError: nil)
        }
        
        let receivedSuccess = expectation(description: "received success")
        
        // when
        conversation.removeParticipant(user, userSession: mockUserSession) { result in
            switch result {
            case .success:
                receivedSuccess.fulfill()
            default: break
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatRemovingParticipantFailForAllConversationTypesButGroups() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        for conversationType in [ZMConversationType.connection, ZMConversationType.oneOnOne, ZMConversationType.`self`, ZMConversationType.invalid] {
            let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
            conversation.remoteIdentifier = UUID()
            conversation.conversationType = conversationType
            
            let receivedError = expectation(description: "received error")
            
            // when
            conversation.removeParticipant(user, userSession: mockUserSession) { result in
                switch result {
                case .failure(let error):
                    if case ConversationRemoveParticipantError.invalidOperation = error {
                        receivedError.fulfill()
                    }
                default: break
                }
            }
            
            XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        }
    }
    
    func testThatRemoveParticipantFailOnInvalidOperation() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members/\(user.remoteIdentifier!.transportString())" else { return nil }
            
            return ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
        }
        
        let receivedError = expectation(description: "received error")
        
        // when
        conversation.removeParticipant(user, userSession: mockUserSession) { result in
            switch result {
            case .failure(let error):
                if case ConversationRemoveParticipantError.invalidOperation = error {
                    receivedError.fulfill()
                }
            default: break
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatRemoveParticipantFailOnConversationNotFound() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members/\(user.remoteIdentifier!.transportString())" else { return nil }
            
            return ZMTransportResponse(payload: ["label": "no-conversation"] as ZMTransportData, httpStatus: 404, transportSessionError: nil)
        }
        
        let receivedError = expectation(description: "received error")
        
        // when
        conversation.removeParticipant(user, userSession: mockUserSession) { result in
            switch result {
            case .failure(let error):
                if case ConversationRemoveParticipantError.conversationNotFound = error {
                    receivedError.fulfill()
                }
            default: break
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatRemoveParticipantForwardEventInResponseToEventConsumers() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()

        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group

        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members/\(user.remoteIdentifier!.transportString())" else { return nil }

            let payload = self.responsePayloadForUserEventInConversation(conversation.remoteIdentifier!, senderId: UUID(), usersIds: [user.remoteIdentifier!], eventType: EventConversationMemberLeave)
            return ZMTransportResponse(payload: payload, httpStatus: 200, transportSessionError: nil)
        }

        let receivedSuccess = expectation(description: "received success")

        // when
        conversation.removeParticipant(user, userSession: mockUserSession) { result in
            switch result {
            case .success:
                receivedSuccess.fulfill()
            default: break
            }
        }
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(processedUpdateEvents.count, 1);
        XCTAssertEqual((processedUpdateEvents.firstObject as? ZMUpdateEvent)?.type, ZMUpdateEventType.conversationMemberLeave)
        
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatClearedTimestampAreUpdatedWhenRemovingSelf() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let selfUser = ZMUser.selfUser(in: uiMOC)
        selfUser.remoteIdentifier = UUID()
        
        let conversationId = UUID()
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = conversationId
        conversation.conversationType = .group;

        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.serverTimestamp = Date()
        conversation.mutableMessages.add(message)
        conversation.lastServerTimeStamp = message.serverTimestamp?.addingTimeInterval(5)
        
        conversation.clearMessageHistory()
        uiMOC.saveOrRollback()
        
        let memberLeaveTimestamp = Date().addingTimeInterval(1000)
        let receivedSuccess = expectation(description: "received success")
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members/\(selfUser.remoteIdentifier!.transportString())" else { return nil }
            
            let payload = self.responsePayloadForUserEventInConversation(conversation.remoteIdentifier!, senderId: UUID(), usersIds: [user.remoteIdentifier!], eventType: EventConversationMemberLeave, time: memberLeaveTimestamp)
            return ZMTransportResponse(payload: payload, httpStatus: 200, transportSessionError: nil)
        }
        
        // when
        conversation.removeParticipant(selfUser, userSession: mockUserSession) { result in
            switch result {
            case .success:
                receivedSuccess.fulfill()
            default: break
            }
        }
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        syncMOC.saveOrRollback()
        
        // then
        syncMOC.performGroupedBlockAndWait {
            let conversation = ZMConversation(remoteID: conversationId, createIfNeeded: false, in: self.syncMOC)!
            XCTAssertEqual(conversation.clearedTimeStamp?.transportString(), memberLeaveTimestamp.transportString())
        }
        
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatClearedTimestampAreNotUpdatedWhenRemovingOtherUser() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let selfUser = ZMUser.selfUser(in: uiMOC)
        selfUser.remoteIdentifier = UUID()
        
        let conversationId = UUID()
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = conversationId
        conversation.conversationType = .group;
        
        let message = ZMClientMessage(nonce: UUID(), managedObjectContext: uiMOC)
        message.serverTimestamp = Date()
        conversation.mutableMessages.add(message)
        conversation.lastServerTimeStamp = message.serverTimestamp?.addingTimeInterval(5)
        
        conversation.clearMessageHistory()
        uiMOC.saveOrRollback()
        
        let clearedTimestamp = conversation.clearedTimeStamp
        let memberLeaveTimestamp = Date().addingTimeInterval(1000)
        let receivedSuccess = expectation(description: "received success")
        
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/conversations/\(conversation.remoteIdentifier!.transportString())/members/\(user.remoteIdentifier!.transportString())" else { return nil }
            
            let payload = self.responsePayloadForUserEventInConversation(conversation.remoteIdentifier!, senderId: UUID(), usersIds: [user.remoteIdentifier!], eventType: EventConversationMemberLeave, time: memberLeaveTimestamp)
            return ZMTransportResponse(payload: payload, httpStatus: 200, transportSessionError: nil)
        }
        
        // when
        conversation.removeParticipant(user, userSession: mockUserSession) { result in
            switch result {
            case .success:
                receivedSuccess.fulfill()
            default: break
            }
        }
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        syncMOC.saveOrRollback()
        
        // then
        syncMOC.performGroupedBlockAndWait {
            let conversation = ZMConversation(remoteID: conversationId, createIfNeeded: false, in: self.syncMOC)!
            XCTAssertEqual(conversation.clearedTimeStamp?.transportString(), clearedTimestamp?.transportString())
        }
        
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    // MARK: - Request Factory
    
    func testThatItCreatesRequestForRemovingService() {
        
        // given
        let service = ZMUser.insertNewObject(in: uiMOC)
        service.remoteIdentifier = UUID()
        service.providerIdentifier = "123"
        service.serviceIdentifier = "123"
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [service])!
        conversation.remoteIdentifier = UUID()
        
        // when
        let request = WireSyncEngine.ConversationParticipantRequestFactory.requestForRemovingParticipant(service, conversation: conversation)
        
        // then
        XCTAssertEqual(request.method, .methodDELETE)
        XCTAssertEqual(request.path, "/conversations/\(conversation.remoteIdentifier!.transportString())/bots/\(service.remoteIdentifier!.transportString())")
    }
    
    func testThatItCreatesRequestForRemovingParticipant() {
        
        // given
        let user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [user])!
        conversation.remoteIdentifier = UUID()
        
        // when
        let request = WireSyncEngine.ConversationParticipantRequestFactory.requestForRemovingParticipant(user, conversation: conversation)
        
        // then
        XCTAssertEqual(request.method, .methodDELETE)
        XCTAssertEqual(request.path, "/conversations/\(conversation.remoteIdentifier!.transportString())/members/\(user.remoteIdentifier!.transportString())")
    }
    
    func testThatItCreatesRequestForAddingParticipants() {
        
        // given
        let user1 = ZMUser.insertNewObject(in: uiMOC)
        user1.remoteIdentifier = UUID()
        
        let user2 = ZMUser.insertNewObject(in: uiMOC)
        user2.remoteIdentifier = UUID()
        
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
        conversation.remoteIdentifier = UUID()
        
        // when
        let request = WireSyncEngine.ConversationParticipantRequestFactory.requestForAddingParticipants(Set(arrayLiteral: user1, user2), conversation: conversation)
        
        // then
        XCTAssertEqual(request.method, .methodPOST)
        XCTAssertEqual(request.path, "/conversations/\(conversation.remoteIdentifier!.transportString())/members")
        
        let usersIdsInPayload = request.payload?.asDictionary()?["users"] as! [String]
        XCTAssertEqual(Set(usersIdsInPayload), Set(arrayLiteral: user1.remoteIdentifier!.transportString(), user2.remoteIdentifier!.transportString()))
    }
    
}
