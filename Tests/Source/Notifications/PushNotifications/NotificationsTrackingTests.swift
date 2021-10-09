//

import XCTest
@testable import WireSyncEngine

final class NotificationsTrackerTests: XCTestCase {
    
    var sut: NotificationsTracker!
    var mockAnalytics: MockAnalytics!
    
    override func setUp() {
        super.setUp()
        mockAnalytics = MockAnalytics()
        sut = NotificationsTracker(analytics: mockAnalytics)
    }
    
    override func tearDown() {
        sut = nil
        mockAnalytics = nil
        super.tearDown()
    }

    func testThatItDoesNotDispatchEventWithNoAttributesSet() {
        // WHEN
        sut.dispatchEvent()

        // THEN
        XCTAssertEqual(mockAnalytics.taggedEvents.count, 0);
        XCTAssertEqual(mockAnalytics.taggedEventsWithAttributes.count, 0);
    }

    func testThatItDoesIncrementCounters_started() {
        // WHEN
        sut.registerReceivedPush()

        // THEN
        let attributes = mockAnalytics.persistedAttributes(for: sut.eventName)
        let identifier = NotificationsTracker.Attributes.startedProcessing.identifier
        XCTAssertNotNil(attributes)
        XCTAssertEqual(attributes?[identifier] as? Int, 1)
    }

    func testThatItDoesIncrementCounters_fetching() {
        // WHEN
        sut.registerStartStreamFetching()

        // THEN
        let attributes = mockAnalytics.persistedAttributes(for: sut.eventName)
        let identifier = NotificationsTracker.Attributes.startedFetchingStream.identifier
        XCTAssertNotNil(attributes)
        XCTAssertEqual(attributes?[identifier] as? Int, 1)
    }

    func testThatItDoesIncrementCounters_completedFetching() {
        // WHEN
        sut.registerFinishStreamFetching()

        // THEN
        let attributes = mockAnalytics.persistedAttributes(for: sut.eventName)
        let identifier = NotificationsTracker.Attributes.finishedFetchingStream.identifier
        XCTAssertNotNil(attributes)
        XCTAssertEqual(attributes?[identifier] as? Int, 1)
    }

    func testThatItDoesIncrementCounters_finished() {
        // WHEN
        sut.registerNotificationProcessingCompleted()

        // THEN
        let attributes = mockAnalytics.persistedAttributes(for: sut.eventName)
        let identifier = NotificationsTracker.Attributes.finishedProcessing.identifier
        XCTAssertNotNil(attributes)
        XCTAssertEqual(attributes?[identifier] as? Int, 1)
    }
    
    func testThatItDoesIncrementCounters_aborted() {
        // WHEN
        sut.registerProcessingAborted()
        
        // THEN
        let attributes = mockAnalytics.persistedAttributes(for: sut.eventName)
        let identifier = NotificationsTracker.Attributes.abortedProcessing.identifier
        XCTAssertNotNil(attributes)
        XCTAssertEqual(attributes?[identifier] as? Int, 1)
    }

    func testThatItIncrementsCounterTwice() {
        // WHEN
        sut.registerReceivedPush()
        sut.registerReceivedPush()

        // THEN
        let attributes = mockAnalytics.persistedAttributes(for: sut.eventName)
        let identifier = NotificationsTracker.Attributes.startedProcessing.identifier
        XCTAssertNotNil(attributes)
        XCTAssertEqual(attributes?[identifier] as? Int, 2)
    }

    func testThatItDispatchesPersistedAttributes() {
        // GIVEN
        sut.registerReceivedPush()
        sut.registerStartStreamFetching()
        sut.registerFinishStreamFetching()
        sut.registerNotificationProcessingCompleted()
        sut.registerProcessingAborted()

        // WHEN
        sut.dispatchEvent()

        // THEN
        let payload: [String : NSObject] = [
            NotificationsTracker.Attributes.startedProcessing.identifier: 1 as NSObject,
            NotificationsTracker.Attributes.startedFetchingStream.identifier: 1 as NSObject,
            NotificationsTracker.Attributes.finishedFetchingStream.identifier: 1 as NSObject,
            NotificationsTracker.Attributes.finishedProcessing.identifier: 1 as NSObject,
            NotificationsTracker.Attributes.abortedProcessing.identifier: 1 as NSObject
        ]
        guard let attributes = mockAnalytics.taggedEventsWithAttributes.first?.attributes else {
            XCTFail(); return
        }
        XCTAssertEqual(payload, attributes)
    }
}
