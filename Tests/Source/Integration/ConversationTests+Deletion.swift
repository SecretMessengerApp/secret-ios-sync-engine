//

import XCTest

class ConversationTests_Deletion: ConversationTestsBase {

    func testThatDeletingAConversationAlsoDeletesItLocally_OnSuccessfulResponse() {
        // GIVEN
        XCTAssertTrue(login())
        createTeamAndConversations()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // WHEN
        let conversationIsDeleted = expectation(description: "Team conversation is deleted")
        let teamConversation = conversation(for: groupConversationWithWholeTeam)!
        teamConversation.delete(in: userSession!, completion: { (result) in
            if case .success = result {
                conversationIsDeleted.fulfill()
            } else {
                XCTFail()
            }
        })
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        XCTAssertTrue(teamConversation.isZombieObject)
    }
    
    func testThatDeletingAConversationIsNotDeletingItLocally_OnFailureResponse() {
        // GIVEN
        XCTAssertTrue(login())
        createTeamAndConversations()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        mockTransportSession.responseGeneratorBlock = {[weak self] request in
            guard request.path == "/teams/\(self!.team.identifier)/conversations/\(self!.groupConversationWithWholeTeam.identifier)" else { return nil }
            
            self?.mockTransportSession.responseGeneratorBlock = nil
            
            return ZMTransportResponse(payload: nil, httpStatus: 403, transportSessionError: nil)
        }
        
        // WHEN
        let conversationDeletionFailed = expectation(description: "Team conversation deletion failed")
        let teamConversation = conversation(for: groupConversationWithWholeTeam)!
        teamConversation.delete(in: userSession!, completion: { (result) in
            if case .failure = result {
                conversationDeletionFailed.fulfill()
            } else {
                XCTFail()
            }
        })
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        XCTAssertFalse(teamConversation.isZombieObject)
    }
    
}
