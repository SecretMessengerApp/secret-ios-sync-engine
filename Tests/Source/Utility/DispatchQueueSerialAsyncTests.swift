//

import Foundation
import XCTest

class DispatchQueueSerialAsyncTests: XCTestCase {
    let sut = DispatchQueue(label: "test")
    
    func testThatItWaitsForOneTaskBeforeAnother() {
        let doneExpectation = self.expectation(description: "Done with jobs")
        
        var done1: Bool = false
        var done2: Bool = false
        
        sut.serialAsync { finally in
            let time = DispatchTime.now() + DispatchTimeInterval.milliseconds(200)
            
            DispatchQueue.global(qos: .background).asyncAfter(deadline: time) {
                XCTAssertFalse(done1)
                XCTAssertFalse(done2)
                done1 = true
                finally()
            }
        }
        
        sut.serialAsync { finally in
            XCTAssertTrue(done1)
            XCTAssertFalse(done2)
            done2 = true
            finally()
            doneExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
        
        XCTAssertTrue(done1)
        XCTAssertTrue(done2)
    }
}
