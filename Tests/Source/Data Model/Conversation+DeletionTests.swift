//

import XCTest
@testable import WireSyncEngine

class Conversation_DeletionTests: MessagingTest {

    func testThatItParsesAllKnownConversationDeletionErrorResponses() {
        
        let errorResponses: [(ConversationDeletionError, ZMTransportResponse)] = [
            (ConversationDeletionError.invalidOperation, ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)),
            (ConversationDeletionError.conversationNotFound, ZMTransportResponse(payload: ["label": "no-conversation"] as ZMTransportData, httpStatus: 404, transportSessionError: nil))
        ]
        
        for (expectedError, response) in errorResponses {
            guard let error = ConversationDeletionError(response: response) else { return XCTFail() }
            
            if case error = expectedError {
                // success
            } else {
                XCTFail()
            }
        }
    }
    
    func testItThatReturnsFailure_WhenAttempingToDeleteNonTeamConveration() {
        // GIVEN
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        let invalidOperationfailure = expectation(description: "Invalid Operation")
        
        // WHEN
        conversation.delete(in: mockUserSession) { (result) in
            if case .failure(let error) = result {
                if case ConversationDeletionError.invalidOperation = error {
                    invalidOperationfailure.fulfill()
                }
            }
        }
        
        // THEN
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testItThatReturnsFailure_WhenAttempingToDeleteLocalConveration() {
        // GIVEN
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
        conversation.conversationType = .group
        conversation.teamRemoteIdentifier = UUID()
        let invalidOperationfailure = expectation(description: "Invalid Operation")
        
        // WHEN
        conversation.delete(in: mockUserSession) { (result) in
            if case .failure(let error) = result {
                if case ConversationDeletionError.invalidOperation = error {
                    invalidOperationfailure.fulfill()
                }
            }
        }
        
        // THEN
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    // MARK:  Request Factory
    
    func testThatItGeneratesRequest_ForDeletingTeamConveration() {
        // GIVEN
        let conversation = ZMConversation.insertGroupConversation(into: uiMOC, withParticipants: [])!
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = .group
        conversation.teamRemoteIdentifier = UUID()
        
        // WHEN
        guard let request = WireSyncEngine.ConversationDeletionRequestFactory.requestForDeletingTeamConversation(conversation) else { return XCTFail() }
        
        // THEN
        XCTAssertEqual(request.path, "/teams/\(conversation.teamRemoteIdentifier!.transportString())/conversations/\(conversation.remoteIdentifier!.transportString())")
    }

}
