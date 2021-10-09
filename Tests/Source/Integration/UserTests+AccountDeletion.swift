//

import XCTest

class UserTests_AccountDeletion: IntegrationTest {

    override func setUp() {
        super.setUp()

        createSelfUserAndConversation()
        createExtraUsersAndConversations()
    }

    func testThatUserIsMarkedAsDeleted() {
        // given
        XCTAssertTrue(login())
        
        // when
        mockTransportSession.performRemoteChanges { (mockTransport) in
            mockTransport.deleteAccount(for: self.user1)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let user1 = self.user(for: self.user1)!
        XCTAssertTrue(user1.isAccountDeleted)
    }
    
    func testThatUserIsRemovedFromAllConversationsWhenDeleted() {
        // given
        XCTAssertTrue(login())
        
        // when
        mockTransportSession.performRemoteChanges { (foo) in
            foo.deleteAccount(for: self.user1)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let user1 = self.user(for: self.user1)!
        let groupConversation = self.conversation(for: self.groupConversation)!
        XCTAssertFalse(groupConversation.activeParticipants.contains(user1))
    }
    
}
