//


import Foundation
import XCTest
import WireTesting
@testable import WireSyncEngine



class AnalyticsTests: ZMTBaseTest {
    
    var analytics: MockAnalytics!
    var directory: ManagedObjectContextDirectory!
    var sharedContainerURL : URL!
    var accountID : UUID!

    func createSyncContext() -> NSManagedObjectContext {
        let expectation = self.expectation(description: "create directory")
        StorageStack.shared.createManagedObjectContextDirectory(accountIdentifier: accountID, applicationContainer: sharedContainerURL) {
            self.directory = $0
            expectation.fulfill()
        }
        XCTAssert(self.waitForCustomExpectations(withTimeout: 0.5))
        return self.directory.syncContext
    }

    override func setUp() {
        super.setUp()
        analytics = MockAnalytics()
        accountID = UUID()
        sharedContainerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    override func tearDown() {
        sharedContainerURL = nil
        directory = nil
        accountID = nil
        analytics = nil
        StorageStack.reset()
        super.tearDown()
    }
    
    func testThatItSetsAnalyticsOnManagedObjectContext() {
        // given
        let context = createSyncContext()
        
        // when
        context.analytics = analytics
        
        // then
        XCTAssertNotNil(context.analytics)
        XCTAssertEqual(context.analytics as? MockAnalytics, analytics)
        context.analytics = nil
        XCTAssertNil(context.analytics)
    }
}

// MARK: - Helpers
struct EventWithAttributes: Equatable {
    let event: String
    let attributes: [String: NSObject]
}

func ==(lhs: EventWithAttributes, rhs: EventWithAttributes) -> Bool {
    return lhs.event == rhs.event && lhs.attributes == rhs.attributes
}

final class MockAnalytics: NSObject, AnalyticsType {

    var eventAttributes = [String : [String : NSObject]]()

    public func setPersistedAttributes(_ attributes: [String : NSObject]?, for event: String) {
        if let attributes = attributes {
            eventAttributes[event] = attributes
        } else {
            eventAttributes.removeValue(forKey: event)
        }
    }

    public func persistedAttributes(for event: String) -> [String : NSObject]? {
        let value = eventAttributes[event] ?? [:]
        return value
    }
    
    @objc func tagEvent(_ event: String) {
        taggedEvents.append(event)
    }
    
    @objc func tagEvent(_ event: String, attributes: [String : NSObject]) {
        taggedEventsWithAttributes.append(EventWithAttributes(event: event, attributes: attributes))
    }
    
    @objc func upload() {
        uploadCallCount += 1
    }
    
    var taggedEvents = [String]()
    var taggedEventsWithAttributes = [EventWithAttributes]()
    var uploadCallCount = 0
}
