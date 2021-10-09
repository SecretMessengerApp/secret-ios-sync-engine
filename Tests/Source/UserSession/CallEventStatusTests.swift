//

import XCTest
import WireTesting

@testable import WireSyncEngine

class CallEventStatusTests: ZMTBaseTest {
    
    var sut: CallEventStatus!

    override func setUp() {
        super.setUp()
        
        sut = CallEventStatus()
        sut.eventProcessingTimoutInterval = 0.1
    }

    override func tearDown() {
        sut = nil
        
        super.tearDown()
    }

    func testThatWaitForCallEventCompleteImmediatelyIfNoCallEventsAreScheduled() {
        
        // expect
        let processingDidComplete = expectation(description: "processingDidComplete")
        
        // when
        let hasUnprocessedCallEvents = sut.waitForCallEventProcessingToComplete {
            processingDidComplete.fulfill()
        }
        
        XCTAssertFalse(hasUnprocessedCallEvents)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatWaitForCallEventCompleteWhenScheduledCallEventIsProcessed() {
        
        // given
        sut.scheduledCallEventForProcessing()
        
        // expect
        let processingDidComplete = expectation(description: "processingDidComplete")
        let hasUnprocessedCallEvents = sut.waitForCallEventProcessingToComplete {
            processingDidComplete.fulfill()
        }
        
        // when
        sut.finishedProcessingCallEvent()
        XCTAssertTrue(hasUnprocessedCallEvents)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatWaitForCallEventCompleteWhenScheduledCallEventIsProcessedWhenTimeoutTimerIsStillRunning() {
        
        // given
        sut.scheduledCallEventForProcessing()
        sut.finishedProcessingCallEvent()
        
        // expect
        let processingDidComplete = expectation(description: "processingDidComplete")
        let hasUnprocessedCallEvents = sut.waitForCallEventProcessingToComplete {
            processingDidComplete.fulfill()
        }
        
        // when
        XCTAssertTrue(hasUnprocessedCallEvents)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }

}
