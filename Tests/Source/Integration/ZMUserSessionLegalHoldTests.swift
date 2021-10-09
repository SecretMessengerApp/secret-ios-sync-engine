//

import Foundation
import WireSyncEngine

class ZMUserSessionLegalHoldTests: IntegrationTest {

    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
    }

    func testThatUserClientIsInsertedWhenUserReceivesLegalHoldRequest() {
        // GIVEN
        var team: MockTeam!

        // 1) I come from a legal-hold enabled team
        mockTransportSession.performRemoteChanges { session in
            team = session.insertTeam(withName: "Team", isBound: true, users: [self.selfUser])
            team.hasLegalHoldService = true
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // 2) I log in
        XCTAssert(login())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        let realSelfUser = user(for: selfUser)!
        XCTAssertEqual(realSelfUser.legalHoldStatus, .disabled)

        // 3) My team admin requests legal hold for me
        mockTransportSession.performRemoteChanges { _ in
            XCTAssertTrue(self.selfUser.requestLegalHold())
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        guard case let .pending(legalHoldRequest) = realSelfUser.legalHoldStatus else {
            return XCTFail("No update event was fired for the incoming legal hold request.")
        }

        // WHEN: I accept the legal hold request
        let completionExpectation = expectation(description: "The request completes.")

        userSession?.accept(legalHoldRequest: legalHoldRequest, password: IntegrationTest.SelfUserPassword) { error in
            XCTAssertNil(error)
            completionExpectation.fulfill()
        }

        // THEN
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 1))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        XCTAssertEqual(realSelfUser.clients.count, 2)
        XCTAssertEqual(realSelfUser.legalHoldStatus, .enabled)
    }

    func testThatLegalHoldClientIsRemovedWhenLegalHoldRequestFails() {
        var team: MockTeam!

        // 1) I come from up a legal-hold enabled team
        mockTransportSession.performRemoteChanges { session in
            team = session.insertTeam(withName: "Team", isBound: true, users: [self.selfUser])
            team.hasLegalHoldService = true
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // 2) I log in
        XCTAssert(login())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        let realSelfUser = user(for: selfUser)!
        XCTAssertEqual(realSelfUser.legalHoldStatus, .disabled)

        // 3) My team admin requests legal hold for me (even though
        mockTransportSession.performRemoteChanges { _ in
            XCTAssertTrue(self.selfUser.requestLegalHold())
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        guard case let .pending(legalHoldRequest) = realSelfUser.legalHoldStatus else {
            return XCTFail("No update event was fired for the incoming legal hold request.")
        }

        // WHEN: I accept the legal hold request with the wrong password
        let completionExpectation = expectation(description: "The request completes.")

        userSession?.accept(legalHoldRequest: legalHoldRequest, password: "I tRieD 3 tImeS!") { error in
            XCTAssertEqual(error, .invalidPassword)
            completionExpectation.fulfill()
        }

        // THEN
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 1))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        XCTAssertEqual(realSelfUser.clients.count, 1)
        XCTAssertEqual(realSelfUser.legalHoldStatus, .pending(legalHoldRequest))
    }

}
