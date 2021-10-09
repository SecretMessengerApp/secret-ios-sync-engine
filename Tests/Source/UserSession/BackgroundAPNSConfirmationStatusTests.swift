//

@testable import WireSyncEngine
import WireTesting
import WireMockTransport

class BackgroundAPNSConfirmationStatusTests : MessagingTest {

    var sut : BackgroundAPNSConfirmationStatus!
    var activityManager : MockBackgroundActivityManager!

    override func setUp() {
        super.setUp()
        application.setBackground()
        activityManager = MockBackgroundActivityManager()
        BackgroundActivityFactory.shared.activityManager = activityManager
        sut = BackgroundAPNSConfirmationStatus(application: application, managedObjectContext: syncMOC)
    }
    
    override func tearDown() {
        activityManager.reset()
        activityManager = nil
        BackgroundActivityFactory.shared.activityManager = nil
        sut.tearDown()
        sut = nil
        super.tearDown()
    }
    
    func testThat_CanSendMessage_IsSetToTrue_NewMessage() {
        // given
        let uuid = UUID.create()
        
        // when
        sut.needsToConfirmMessage(uuid)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(sut.needsToSyncMessages)
    }
    
    func testThat_CanSendMessage_IsSetToFalse_MessageConfirmed() {
        // given
        let uuid = UUID.create()
        sut.needsToConfirmMessage(uuid)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // when
        sut.didConfirmMessage(uuid)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertFalse(sut.needsToSyncMessages)
    }
    
    func testThat_CanSendMessage_IsSetToTrue_OneMessageConfirmed_OneMessageNew() {
        // given
        let uuid1 = UUID.create()
        let uuid2 = UUID.create()

        sut.needsToConfirmMessage(uuid1)
        sut.needsToConfirmMessage(uuid2)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // when
        sut.didConfirmMessage(uuid1)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertTrue(sut.needsToSyncMessages)
    }
    
    func testThat_CanSendMessage_IsSetToFalse_MessageTimedOut() {
        // given
        let uuid1 = UUID.create()
        
        sut.needsToConfirmMessage(uuid1)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // when
        activityManager.triggerExpiration()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(sut.needsToSyncMessages)
    }
    
    func testThatItExpiresMultipleMessages() {
        // given
        let uuid1 = UUID.create()
        let uuid2 = UUID.create()
        
        sut.needsToConfirmMessage(uuid1)
        sut.needsToConfirmMessage(uuid2)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // when
        activityManager.triggerExpiration()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(sut.needsToSyncMessages)
    }
}

