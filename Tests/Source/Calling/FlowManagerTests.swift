//


import Foundation
import avs
@testable import WireSyncEngine


class FlowManagerTests : MessagingTest {
    func testThatItSendsNotificationWhenFlowManagerIsCreated() {
        // GIVEN
        let expectation = self.expectation(description: "Notification is sent")
        let notificationObserver = NotificationCenter.default.addObserver(forName: FlowManager.AVSFlowManagerCreatedNotification, object: nil, queue: nil) { _ in
            expectation.fulfill()
        }

        // WHEN
        _ = FlowManager(mediaManager: MockMediaManager())

        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        NotificationCenter.default.removeObserver(notificationObserver)
    }
}
