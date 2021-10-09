//

import Foundation

import Foundation
@testable import WireSyncEngine

class UserRichProfileIntegrationTests : IntegrationTest {
    
    override func setUp() {
        super.setUp()
        
        createSelfUserAndConversation()
        createExtraUsersAndConversations()
        createTeamAndConversations()
    }
    
    func testThatItDoesNotUpdateRichInfoIfItDoesNotHaveIt() {
        // given
        XCTAssertTrue(login())
        
        // when
        let user = self.user(for: teamUser1)
        XCTAssertEqual(user?.richProfile.isEmpty, true)
        userSession?.performChanges {
            user?.needsRichProfileUpdate = true
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(user?.richProfile.isEmpty, true)
    }
    
    func testThatItHandlesErrorWhenUpdatingRichInfo() {
        // given
        let entry1 = UserRichProfileField(type: "email", value: "some@email.com")
        let entry2 = UserRichProfileField(type: "position", value: "Chief Testing Officer")

        mockTransportSession.performRemoteChanges {
            self.team = $0.insertTeam(withName: "Name", isBound: true)
            $0.insertMember(with: self.selfUser, in: self.team)
            _ = $0.insertTeam(withName: "Other", isBound: false, users:[self.user1])
            self.user1.appendRichInfo(type: entry1.type, value: entry1.value)
            self.user1.appendRichInfo(type: entry2.type, value: entry2.value)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        XCTAssertTrue(login())
        
        // when
        let user = self.user(for: user1)
        userSession?.performChanges {
            user?.needsRichProfileUpdate = true
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(user?.richProfile, [])
    }
    
    func testThatItUpdatesRichInfoWhenItDoesHaveIt() {
        // given
        let entry1 = UserRichProfileField(type: "email", value: "some@email.com")
        let entry2 = UserRichProfileField(type: "position", value: "Chief Testing Officer")
        mockTransportSession.performRemoteChanges { _ in
            self.teamUser1.appendRichInfo(type: entry1.type, value: entry1.value)
            self.teamUser1.appendRichInfo(type: entry2.type, value: entry2.value)
        }
        XCTAssertTrue(login())

        // when
        let user = self.user(for: teamUser1)
        userSession?.performChanges {
            user?.needsRichProfileUpdate = true
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertEqual(user?.richProfile, [entry1, entry2])
    }
    
}
