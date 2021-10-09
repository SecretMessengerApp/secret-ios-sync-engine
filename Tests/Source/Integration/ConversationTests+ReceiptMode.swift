////

import XCTest

class ConversationTests_ReceiptMode: IntegrationTest {

    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
        createExtraUsersAndConversations()
        createTeamAndConversations()
    }
        
    func testThatItUpdatesTheReadReceiptsSetting() {
        // given
        XCTAssert(login())
        let sut = conversation(for: groupConversation)!
        XCTAssertFalse(sut.hasReadReceiptsEnabled)
        
        // when
        sut.setEnableReadReceipts(true, in: userSession!) { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case .success:
                break
            }
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        
        // then
        XCTAssertTrue(sut.hasReadReceiptsEnabled)
    }
    
    func testThatItUpdatesTheReadReceiptsSettingWhenOutOfSyncWithBackend() {
        // given
        XCTAssert(login())
        let sut = conversation(for: groupConversation)!
        XCTAssertFalse(sut.hasReadReceiptsEnabled)
        
        mockTransportSession.performRemoteChanges { _ in
            self.groupConversation.receiptMode = 1
        }
        
        // when
        sut.setEnableReadReceipts(true, in: userSession!) { (result) in
            switch result {
            case .failure(_):
                XCTFail()
            case .success:
                break
            }
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        
        // then
        XCTAssertTrue(sut.hasReadReceiptsEnabled)
    }
    
    func testThatItUpdatesTheReadReceiptsSettingWhenChangedRemotely() {
        // given
        XCTAssert(login())
        let sut = conversation(for: groupConversation)!
        XCTAssertFalse(sut.hasReadReceiptsEnabled)
        
        // when
        mockTransportSession.performRemoteChanges { (foo) in
            self.groupConversation.changeReceiptMode(by: self.user1, receiptMode: 1)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        
        // then
        XCTAssertTrue(sut.hasReadReceiptsEnabled)
    }
    
    func testThatItWeCantChangeTheReadReceiptsSettingInAOneToOneConversation() {
        // given
        XCTAssert(login())
        let sut = conversation(for: selfToUser1Conversation)!
        XCTAssertFalse(sut.hasReadReceiptsEnabled)
        let expectation = self.expectation(description: "Invalid Operation")
        
        // when
        sut.setEnableReadReceipts(true, in: userSession!) { (result) in
            switch result {
            case .failure(ReadReceiptModeError.invalidOperation):
                expectation.fulfill()
            default:
                XCTFail()
            }
        }
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.1))
    }

}
