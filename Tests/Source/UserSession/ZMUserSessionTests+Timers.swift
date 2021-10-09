////

import Foundation
import XCTest

class ZMUserSessionTimersTests : ZMUserSessionTestsBase {
    
    func testThatTimersAreStartedWhenUserSessionIsCreated() {
        // then
        XCTAssertNotNil(sut.managedObjectContext.zm_messageDeletionTimer)
        sut.syncManagedObjectContext.performGroupedAndWait {
            XCTAssertNotNil($0.zm_messageObfuscationTimer)
        }
    }
}
