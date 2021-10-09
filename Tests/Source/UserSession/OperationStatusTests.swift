//

import Foundation

@testable import WireSyncEngine 

class OperationStatusTests : MessagingTest {
    
    fileprivate var sut : OperationStatus!
    
    
    override func setUp() {
        super.setUp()
        
        sut = OperationStatus()
    }
    
    override func tearDown() {
        sut = nil
        
        super.tearDown()
    }
    
    func testOperationState_whenInForeground() {
        // when
        sut.isInBackground = false
        
        // then
        XCTAssertEqual(sut.operationState, .foreground)
    }
    
    func testOperationState_whenInBackground() {
        // when
        sut.isInBackground = true
        
        // then
        XCTAssertEqual(sut.operationState, .background)
    }
    
    func testOperationState_whenInBackgroundWithOngoingCall() {
        // when
        sut.isInBackground = true
        sut.hasOngoingCall = true
        
        // then
        XCTAssertEqual(sut.operationState, .backgroundCall)
    }
    
    func testThatBackgroundTaskIsUpdatingOperationState() {
        
        // given
        sut.isInBackground = true
        let handlerCalled = expectation(description: "background task handler called")
        
        // when
        sut.startBackgroundTask { (result) in
            handlerCalled.fulfill()
        }
        
        // then
        XCTAssertEqual(sut.operationState, .backgroundTask)
        
        // when
        sut.finishBackgroundTask(withTaskResult: .finished)
        OperationStatusTests.performRunLoopTick()
        
        // then
        XCTAssertEqual(sut.operationState, .background)
    }
    
    func testThatBackgroundFetchIsUpdatingOperationState() {
        
        // given
        sut.isInBackground = true
        let handlerCalled = expectation(description: "background fetch handler called")
        
        // when
        sut.startBackgroundFetch(withCompletionHandler: { (result) in
            handlerCalled.fulfill()
        })
        
        // then
        XCTAssertEqual(sut.operationState, .backgroundFetch)
        OperationStatusTests.performRunLoopTick()
        
        // when
        sut.finishBackgroundFetch(withFetchResult: .noData)
        OperationStatusTests.performRunLoopTick()
        
        // then
        XCTAssertEqual(sut.operationState, .background)
    }
    
    func testThatStartingMultipleBackgroundTasksFail() {
        
        let successHandler = expectation(description: "background task handler called with success result")
        let failureHandler = expectation(description: "background task handler called with failure result")
        
        // given
        sut.startBackgroundTask(withCompletionHandler: { (result) in
            // expect
            if result == BackgroundTaskResult.finished {
                successHandler.fulfill()
            }
        })
        
        // when
        sut.startBackgroundTask(withCompletionHandler: { (result) in
            // expect
            if result == BackgroundTaskResult.failed {
                failureHandler.fulfill()
            }
        })
        
        sut.finishBackgroundTask(withTaskResult: .finished)
    }
    
    func testThatStartingMultipleBackgroundFetchesFail() {
        
        let successHandler = expectation(description: "background fetch handler called with success result")
        let failureHandler = expectation(description: "background fetch handler called with failure result")
        
        // given
        sut.startBackgroundFetch(withCompletionHandler: { (result) in
            // expect
            if result == UIBackgroundFetchResult.noData {
                successHandler.fulfill()
            }
        })
        
        // when
        sut.startBackgroundFetch(withCompletionHandler: { (result) in
            // expect
            if result == UIBackgroundFetchResult.failed {
                failureHandler.fulfill()
            }
        })
        
        sut.finishBackgroundFetch(withFetchResult: .noData)
    }
    
    func testBackgroundTaskFailAfterTimeout() {
        let failureHandler = expectation(description: "background task handler called with failure result")
        
        // given
        sut.startBackgroundTask(timeout: 1.0) { (result) in
            if result == .failed {
                failureHandler.fulfill()
            }
        }
        
        // when
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(sut.operationState, .background)
    }
    
    func testBackgroundFetchFailAfterTimeout() {
        let failureHandler = expectation(description: "background fetch handler called with failure result")
        
        // given
        sut.startBackgroundFetch(timeout: 1.0) { (result) in
            if result == .failed {
                failureHandler.fulfill()
            }
        }
        
        // when
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(sut.operationState, .background)
    }
    
}
