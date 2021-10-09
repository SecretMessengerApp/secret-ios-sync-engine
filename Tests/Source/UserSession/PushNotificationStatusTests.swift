

@testable import WireSyncEngine
import WireTesting
import WireMockTransport

// MARK: - Mocks

@objc class FakeGroupQueue : NSObject, ZMSGroupQueue {
    
    var dispatchGroup : ZMSDispatchGroup! {
        return nil
    }
    
    func performGroupedBlock(_ block : @escaping () -> Void) {
        block()
    }
    
}

// MARK: - Tests

class PushNotificationStatusTests: MessagingTest {
    
    var sut: PushNotificationStatus!
    
    
    override func setUp() {
        super.setUp()
        
        sut = PushNotificationStatus(managedObjectContext: syncMOC)
    }
    
    override func tearDown() {
        sut = nil
        
        super.tearDown()
    }
    
    func testThatStatusIsInProgressWhenAddingEventIdToFetch() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        
        
        // when
        sut.fetch(eventId: eventId) { }
        
        // then
        XCTAssertEqual(sut.status, .inProgress)
    }
    
    func testThatStatusIsInProgressWhenNotAllEventsIdsHaveBeenFetched() {
        // given
        let eventId1 = UUID.timeBasedUUID() as UUID
        let eventId2 = UUID.timeBasedUUID() as UUID
        
        sut.fetch(eventId: eventId1) { }
        sut.fetch(eventId: eventId2) { }
        
        // when
        sut.didFetch(eventIds: [eventId1], lastEventId: eventId1, finished: true)
        
        // then
        XCTAssertEqual(sut.status, .inProgress)
    }
    
    func testThatStatusIsDoneAfterEventIdIsFetched() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        sut.fetch(eventId: eventId) { }
        
        // when
        sut.didFetch(eventIds: [eventId], lastEventId: eventId, finished: true)
        
        // then
        XCTAssertEqual(sut.status, .done)
    }
    
    func testThatStatusIsDoneAfterEventIdIsFetchedEvenIfMoreEventsWillBeFetched() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        sut.fetch(eventId: eventId) { }
        
        // when
        sut.didFetch(eventIds: [eventId], lastEventId: eventId, finished: false)
        
        // then
        XCTAssertEqual(sut.status, .done)
    }
    
    func testThatStatusIsDoneAfterEventIdIsFetchedEvenIfNoEventsWereDownloaded() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        sut.fetch(eventId: eventId) { }
        
        // when
        sut.didFetch(eventIds: [], lastEventId: eventId, finished: true)
        
        // then
        XCTAssertEqual(sut.status, .done)
    }
    
    func testThatStatusIsDoneIfEventsCantBeFetched() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        sut.fetch(eventId: eventId) { }
        
        // when
        sut.didFailToFetchEvents()
        
        // then
        XCTAssertEqual(sut.status, .done)
    }
    
    func testThatCompletionHandlerIsNotCalledIfAllEventsHaveNotBeenFetched() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        
        // expect
        sut.fetch(eventId: eventId) {
            XCTFail("Didn't expect completion handler to be called")
        }
        
        // when
        sut.didFetch(eventIds: [eventId], lastEventId: eventId, finished: false)
        
        // then
        XCTAssertEqual(sut.status, .done)
    }
    
    func testThatCompletionHandlerIsCalledAfterAllEventsHaveBeenFetched() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        let expectation = self.expectation(description: "completion handler was called")
        
        // expect
        sut.fetch(eventId: eventId) {
            expectation.fulfill()
        }
        
        // when
        sut.didFetch(eventIds: [eventId], lastEventId: eventId, finished: true)
        
        // then
        XCTAssertEqual(sut.status, .done)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatCompletionHandlerIsCalledEvenIfNoEventsWereDownloaded() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        let expectation = self.expectation(description: "completion handler was called")
        
        // expect
        sut.fetch(eventId: eventId) {
            expectation.fulfill()
        }
        
        // when
        sut.didFetch(eventIds: [], lastEventId: eventId, finished: true)
        
        // then
        XCTAssertEqual(sut.status, .done)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatCompletionHandlerIsCalledImmediatelyIfEventHasAlreadyBeenFetched() {
        // given
        let eventId = UUID.timeBasedUUID() as UUID
        let expectation = self.expectation(description: "completion handler was called")
        syncMOC.zm_lastNotificationID = eventId

        // when
        sut.fetch(eventId: eventId) {
            expectation.fulfill()
        }
        
        // then
        XCTAssertEqual(sut.status, .done)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
}

