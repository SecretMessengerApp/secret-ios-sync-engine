//


import WireTesting
@testable import WireSyncEngine

class EventDecoderTest: MessagingTest {
    
    var eventMOC: NSManagedObjectContext!
    var sut : EventDecoder!
    
    override func setUp() {
        super.setUp()
        eventMOC = NSManagedObjectContext.createEventContext(withSharedContainerURL: sharedContainerURL, userIdentifier: userIdentifier)
        sut = EventDecoder(eventMOC: eventMOC, syncMOC: syncMOC)
        eventMOC.add(dispatchGroup)

        let selfUser = ZMUser.selfUser(in: syncMOC)
        selfUser.remoteIdentifier = userIdentifier
        let selfConversation = ZMConversation.insertNewObject(in: syncMOC)
        selfConversation.remoteIdentifier = userIdentifier
        selfConversation.conversationType = .self
        syncMOC.saveOrRollback()
    }
    
    override func tearDown() {
        EventDecoder.testingBatchSize = nil
        eventMOC.tearDownEventMOC()
        eventMOC = nil
        sut = nil
        super.tearDown()
    }
}

// MARK: - Processing events
extension EventDecoderTest {
    
    func testThatItProcessesEvents() {
        
        var didCallBlock = false
        
        syncMOC.performGroupedBlock {
            // given
            let event = self.eventStreamEvent()
            
            // when
            self.sut.processEvents([event]) { (events) in
                XCTAssertTrue(events.contains(event))
                didCallBlock = true
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(didCallBlock)
    }
    
    func testThatItProcessesPreviouslyStoredEventsFirst() {
        
        EventDecoder.testingBatchSize = 1
        var callCount = 0
        
        syncMOC.performGroupedBlock {
            // given
            let event1 = self.eventStreamEvent()
            let event2 = self.eventStreamEvent()
            self.insert([event1])
            
            // when
            
            self.sut.processEvents([event2]) { (events) in
                if callCount == 0 {
                    XCTAssertTrue(events.contains(event1))
                } else if callCount == 1 {
                    XCTAssertTrue(events.contains(event2))
                } else {
                    XCTFail("called too often")
                }
                callCount += 1
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(callCount, 2)
    }
    
    func testThatItProcessesInBatches() {
        
        EventDecoder.testingBatchSize = 2
        var callCount = 0
        
        syncMOC.performGroupedBlock {
            
            // given
            let event1 = self.eventStreamEvent()
            let event2 = self.eventStreamEvent()
            let event3 = self.eventStreamEvent()
            let event4 = self.eventStreamEvent()
            
            self.insert([event1, event2, event3])
            
            // when
            self.sut.processEvents([event4]) { (events) in
                if callCount == 0 {
                    XCTAssertTrue(events.contains(event1))
                    XCTAssertTrue(events.contains(event2))
                } else if callCount == 1 {
                    XCTAssertTrue(events.contains(event3))
                    XCTAssertTrue(events.contains(event4))
                }
                else {
                    XCTFail("called too often")
                }
                callCount += 1
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(callCount, 2)
    }
    
    func testThatItDoesNotProcessTheSameEventsTwiceWhenCalledSuccessively() {
        
        EventDecoder.testingBatchSize = 2
        
        syncMOC.performGroupedBlock {
            
            // given
            let event1 = self.eventStreamEvent()
            let event2 = self.eventStreamEvent()
            let event3 = self.eventStreamEvent()
            let event4 = self.eventStreamEvent()
            
            self.insert([event1])
            
            self.sut.processEvents([event2]) { (events) in
                XCTAssert(events.contains(event1))
                XCTAssert(events.contains(event2))
            }
            
            self.insert([event3], startIndex: 1)
            
            // when
            self.sut.processEvents([event4]) { (events) in
                XCTAssertFalse(events.contains(event1))
                XCTAssertFalse(events.contains(event2))
                XCTAssertTrue(events.contains(event3))
                XCTAssertTrue(events.contains(event4))
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
    
    func testThatItDoesNotProcessEventsFromOtherUsersArrivingInSelfConversation() {
        var didCallBlock = false
        
        syncMOC.performGroupedBlock {
            // given
            let event1 = self.eventStreamEvent(conversation: ZMConversation.selfConversation(in: self.syncMOC), genericMessage: ZMGenericMessage.message(content: ZMCalling.calling(message: "123")))
            let event2 = self.eventStreamEvent()
            
            self.insert([event1, event2])
            
            // when
            self.sut.processEvents([]) { (events) in
                XCTAssertEqual(events, [event2])
                didCallBlock = true
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(didCallBlock)
    }
    
    func testThatItDoesProcessEventsFromSelfUserArrivingInSelfConversation() {
        var didCallBlock = false
        
        syncMOC.performGroupedBlock {
            // given
            let callingBessage = ZMGenericMessage.message(content: ZMCalling.calling(message: "123"))
            
            let event1 = self.eventStreamEvent(conversation: ZMConversation.selfConversation(in: self.syncMOC), genericMessage: callingBessage, from: ZMUser.selfUser(in: self.syncMOC))
            let event2 = self.eventStreamEvent()
            
            self.insert([event1, event2])
            
            // when
            self.sut.processEvents([]) { (events) in
                XCTAssertEqual(events, [event1, event2])
                didCallBlock = true
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(didCallBlock)
    }
    
    func testThatItProcessAvailabilityEventsFromOtherUsersArrivingInSelfConversation() {
        var didCallBlock = false
        
        syncMOC.performGroupedBlock {
            // given
            let event1 = self.eventStreamEvent(conversation: ZMConversation.selfConversation(in: self.syncMOC), genericMessage: ZMGenericMessage.message(content: ZMAvailability.availability(.away)))
            let event2 = self.eventStreamEvent()
            
            self.insert([event1, event2])
            
            // when
            self.sut.processEvents([]) { (events) in
                XCTAssertEqual(events, [event1, event2])
                didCallBlock = true
            }
        }
        
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(didCallBlock)
    }
    
}

// MARK: - Already seen events
extension EventDecoderTest {
    
    func testThatItProcessesEventsWithDifferentUUIDWhenThroughPushEventsFirst() {
        
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let pushProcessed = self.expectation(description: "Push event processed")
            let pushEvent = self.pushNotificationEvent()
            let streamEvent = self.eventStreamEvent()
            
            // when
            self.sut.processEvents([pushEvent]) { (events) in
                XCTAssertTrue(events.contains(pushEvent))
                pushProcessed.fulfill()
            }
            
            // then
            XCTAssert(self.waitForCustomExpectations(withTimeout: 0.5))
            
            // and when
            let streamProcessed = self.expectation(description: "Push event processed")
            self.sut.processEvents([streamEvent]) { (events) in
                XCTAssertTrue(events.contains(streamEvent))
                streamProcessed.fulfill()
            }
            
            // then
            XCTAssert(self.waitForCustomExpectations(withTimeout: 0.5))
        }
    }
    
    func testThatItDoesNotProcessesEventsWithSameUUIDWhenThroughPushEventsFirst() {

        syncMOC.performGroupedBlockAndWait {

            // given
            let pushProcessed = self.expectation(description: "Push event processed")
            let uuid = UUID.create()
            let pushEvent = self.pushNotificationEvent(uuid: uuid)
            let streamEvent = self.eventStreamEvent(uuid: uuid)
            
            // when
            self.sut.processEvents([pushEvent]) { (events) in
                XCTAssertTrue(events.contains(pushEvent))
                pushProcessed.fulfill()
            }
            
            // then
            XCTAssert(self.waitForCustomExpectations(withTimeout: 0.5))
            
            // and when
            let streamProcessed = self.expectation(description: "Push event processed")
            self.sut.processEvents([streamEvent]) { (events) in
                XCTAssertTrue(events.isEmpty)
                streamProcessed.fulfill()
            }

            // then
            XCTAssert(self.waitForCustomExpectations(withTimeout: 0.5))
        }
    }
    
    func testThatItProcessesEventsWithSameUUIDWhenThroughPushEventsFirstAndDiscarding() {
        
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let pushProcessed = self.expectation(description: "Push event processed")
            let uuid = UUID.create()
            let pushEvent = self.pushNotificationEvent(uuid: uuid)
            let streamEvent = self.eventStreamEvent(uuid: uuid)
            
            // when
            self.sut.processEvents([pushEvent]) { (events) in
                XCTAssertTrue(events.contains(pushEvent))
                pushProcessed.fulfill()
            }
            self.sut.discardListOfAlreadyReceivedPushEventIDs()
            
            // then
            XCTAssert(self.waitForCustomExpectations(withTimeout: 0.5))
            
            // and when
            let streamProcessed = self.expectation(description: "Push event processed")
            self.sut.processEvents([streamEvent]) { (events) in
                XCTAssertTrue(events.contains(streamEvent))
                streamProcessed.fulfill()
            }
            
            // then
            XCTAssert(self.waitForCustomExpectations(withTimeout: 0.5))
        }
    }
    
}


// MARK: - Helpers
extension EventDecoderTest {
    /// Returns an event from the notification stream
    func eventStreamEvent(uuid: UUID? = nil) -> ZMUpdateEvent {
        let conversation = ZMConversation.insertNewObject(in: syncMOC)
        conversation.remoteIdentifier = UUID.create()
        let payload = payloadForMessage(in: conversation, type: EventConversationAdd, data: ["foo": "bar"])!
        return ZMUpdateEvent(fromEventStreamPayload: payload, uuid: uuid ?? UUID.create())!
    }
    
    func eventStreamEvent(conversation: ZMConversation, genericMessage: ZMGenericMessage, from user: ZMUser? = nil, uuid: UUID? = nil) -> ZMUpdateEvent {
        var payload : ZMTransportData
        if let user = user {
            payload = payloadForMessage(in: conversation, type: EventConversationAddOTRMessage, data: ["text": genericMessage.data().base64EncodedString()], time: nil, from: user)!
        } else {
            payload = payloadForMessage(in: conversation, type: EventConversationAddOTRMessage, data: ["text": genericMessage.data().base64EncodedString()])!
        }
        
        return ZMUpdateEvent(fromEventStreamPayload: payload, uuid: uuid ?? UUID.create())!
    }
    
    /// Returns an event from a push notification
    func pushNotificationEvent(uuid: UUID? = nil) -> ZMUpdateEvent {
        let conversation = ZMConversation.insertNewObject(in: syncMOC)
        conversation.remoteIdentifier = UUID.create()
        let innerPayload = payloadForMessage(in: conversation, type: EventConversationAdd, data: ["foo": "bar"])!
        let payload = [
            "id" : (uuid ?? UUID.create()).transportString(),
            "payload" : [innerPayload],
        ] as [String : Any]
        let events = ZMUpdateEvent.eventsArray(from: payload as NSDictionary, source: .pushNotification)
        return events!.first!
    }
    
    func insert(_ events: [ZMUpdateEvent], startIndex: Int64 = 0) {
        eventMOC.performGroupedBlockAndWait {
            events.enumerated().forEach { index, event  in
                let _ = StoredUpdateEvent.create(event, managedObjectContext: self.eventMOC, index: Int64(startIndex) + Int64(index))
            }
            
            XCTAssert(self.eventMOC.saveOrRollback())
        }
    }
    
}
