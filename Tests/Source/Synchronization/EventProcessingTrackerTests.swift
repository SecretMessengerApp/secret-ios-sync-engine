//

import XCTest
@testable import WireSyncEngine

final class EventProcessingTrackerTests: XCTestCase {
    
    var sut: EventProcessingTracker!
    
    override func setUp() {
        super.setUp()
        sut = EventProcessingTracker()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testThatItIncrementCounters_savesPerformed_debugDescription() {
        //given
        XCTAssertEqual(sut.debugDescription, "Optional([:])")

        //when
        sut.registerSavePerformed()

        //then
        XCTAssertEqual(sut.debugDescription, "Optional([\"event_savesPerformed\": 1])")
    }

    func testThatItIncrementCounters_savesPerformed() {
        //when
        sut.registerSavePerformed()
        
        //then
        verifyIncrement(attribute: .savesPerformed)
    }
    
    func testThatItIncrementCounters_processedEvents() {
        //when
        sut.registerEventProcessed()
        
        //then
        verifyIncrement(attribute: .processedEvents)
    }
    
    func testThatItIncrementCounters_dataUpdatePerformed() {
        //when
        sut.registerDataUpdatePerformed()
        
        //then
        verifyIncrement(attribute: .dataUpdatePerformed)
    }
    
    func testThatItIncrementCounters_dataDeletionPerformed() {
        //when
        sut.registerDataDeletionPerformed()
        
        //then
        verifyIncrement(attribute: .dataDeletionPerformed)
    }
    
    func testThatItIncrementCounters_dataInsertionPerformed() {
        //when
        sut.registerDataInsertionPerformed()
        
        //then
        verifyIncrement(attribute: .dataInsertionPerformed)
    }
    
    func testMultipleIncrements() {
        //when
        sut.registerSavePerformed()
        sut.registerEventProcessed()
        sut.registerDataUpdatePerformed()
        sut.registerDataDeletionPerformed()
        sut.registerDataInsertionPerformed()
        
        //then
        verifyIncrement(attribute: .dataInsertionPerformed)
        verifyIncrement(attribute: .dataDeletionPerformed)
        verifyIncrement(attribute: .dataUpdatePerformed)
        verifyIncrement(attribute: .processedEvents)
        verifyIncrement(attribute: .savesPerformed)
    }
    
    func verifyIncrement(attribute: EventProcessingTracker.Attributes) {
        let attributes = sut.persistedAttributes(for: sut.eventName)
        XCTAssertNotNil(attributes)
        XCTAssertEqual(attributes[attribute.identifier] as? Int, 1)
    }
    
}
