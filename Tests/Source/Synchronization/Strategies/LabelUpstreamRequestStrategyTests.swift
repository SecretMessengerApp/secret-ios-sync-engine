//

import XCTest
@testable import WireSyncEngine

class LabelUpstreamRequestStrategyTests: MessagingTest {
    
    var sut: LabelUpstreamRequestStrategy!
    var mockSyncStatus: MockSyncStatus!
    var mockSyncStateDelegate: MockSyncStateDelegate!
    var mockApplicationStatus: MockApplicationStatus!
    
    var conversation1: ZMConversation!
    var conversation2: ZMConversation!
    
    override func setUp() {
        super.setUp()
        mockApplicationStatus = MockApplicationStatus()
        mockApplicationStatus.mockSynchronizationState = .eventProcessing
        sut = LabelUpstreamRequestStrategy(withManagedObjectContext: syncMOC, applicationStatus: mockApplicationStatus)
        
        syncMOC.performGroupedBlockAndWait {
            self.conversation1 = ZMConversation.insertNewObject(in: self.syncMOC)
            self.conversation1.remoteIdentifier = UUID()
            
            self.conversation2 = ZMConversation.insertNewObject(in: self.syncMOC)
            self.conversation2.remoteIdentifier = UUID()
        }
    }
    
    override func tearDown() {
        sut = nil
        mockSyncStatus = nil
        mockApplicationStatus = nil
        mockSyncStateDelegate = nil
        conversation1 = nil
        conversation2 = nil
        super.tearDown()
    }
    
    func testThatItGeneratesRequestForUpdatingLabels() throws {
        let labelUpdate = WireSyncEngine.LabelUpdate(id: Label.fetchFavoriteLabel(in: uiMOC).remoteIdentifier!, type: 1, name: nil, conversations: [conversation1.remoteIdentifier!])
        let expectedPayload = WireSyncEngine.LabelPayload(labels: [labelUpdate])

        syncMOC.performGroupedBlockAndWait {
            // given
            let label = Label.fetchFavoriteLabel(in: self.syncMOC)
            label.conversations = Set([self.conversation1])
            label.modifiedKeys = Set(["conversations"])
            self.sut.objectsDidChange(Set([label]))
            
            // when
            guard let request = self.sut.nextRequestIfAllowed() else { return XCTFail() }
            
            // then
            let payload = try! JSONSerialization.data(withJSONObject: request.payload as Any, options: [])
            let decodedPayload = try! JSONDecoder().decode(WireSyncEngine.LabelPayload.self, from: payload)
            XCTAssertEqual(request.path, "/properties/labels")
            XCTAssertEqual(decodedPayload, expectedPayload)
        }
    }
    
    func testThatItDoesntUploadLabelsMarkedForDeletion() {
        let labelUpdate = WireSyncEngine.LabelUpdate(id: Label.fetchFavoriteLabel(in: uiMOC).remoteIdentifier!, type: 1, name: nil, conversations: [])
        let expectedPayload = WireSyncEngine.LabelPayload(labels: [labelUpdate])
        
        syncMOC.performGroupedBlockAndWait {
            // given
            var created = false
            let label = Label.fetchOrCreate(remoteIdentifier: UUID(), create: true, in: self.syncMOC, created: &created)!
            label.conversations = Set([self.conversation1])
            label.markForDeletion()
            label.modifiedKeys = Set(["conversations", "markedForDeletion"])
            self.sut.objectsDidChange(Set([label]))
            
            // when
            guard let request = self.sut.nextRequestIfAllowed() else { return XCTFail() }
            
            // then
            let payload = try! JSONSerialization.data(withJSONObject: request.payload as Any, options: [])
            let decodedPayload = try! JSONDecoder().decode(WireSyncEngine.LabelPayload.self, from: payload)
            XCTAssertEqual(request.path, "/properties/labels")
            XCTAssertEqual(decodedPayload, expectedPayload)
        }
    }
        
    func testThatItUploadLabels_WhenModifyingConversations() {
        // given
        syncMOC.performGroupedBlockAndWait {
            let label = Label.insertNewObject(in: self.syncMOC)
            label.modifiedKeys = Set(["conversations"])
            self.sut.objectsDidChange(Set([label]))
        }
        
        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNotNil(self.sut.nextRequestIfAllowed())
        }
    }
    
    func testThatItUploadLabels_WhenModifyingName() {
        // given
        syncMOC.performGroupedBlockAndWait {
            let label = Label.insertNewObject(in: self.syncMOC)
            label.modifiedKeys = Set(["name"])
            self.sut.objectsDidChange(Set([label]))
        }
        
        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNotNil(self.sut.nextRequestIfAllowed())
        }
    }
    
    func testThatItUploadsLabels_WhenModifiedWhileUploadingLabels() {
        var label1: Label!
        var label2: Label!
        
        // given
        syncMOC.performGroupedBlockAndWait {
            label1 = Label.insertNewObject(in: self.syncMOC)
            label2 = Label.insertNewObject(in: self.syncMOC)
            label1.modifiedKeys = Set(["name"])
            self.syncMOC.saveOrRollback()
            self.sut.objectsDidChange(Set([label1]))
        }
        
        // when
        syncMOC.performGroupedBlockAndWait {
            guard let request = self.sut.nextRequestIfAllowed() else { return XCTFail() }
            label2.modifiedKeys = Set(["name"])
            self.syncMOC.saveOrRollback()
            self.sut.objectsDidChange(Set([label2]))
            request.complete(with: ZMTransportResponse(payload: nil, httpStatus: 201, transportSessionError: nil))
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNotNil(self.sut.nextRequestIfAllowed())
        }
    }
    
    func testThatItResetsLocallyModifiedKeys_AfterSuccessfullyUploadingLabels() {
        var label: Label!
        
        // given
        syncMOC.performGroupedBlockAndWait {
            label = Label.insertNewObject(in: self.syncMOC)
            label.modifiedKeys = Set(["name"])
            self.sut.objectsDidChange(Set([label]))
        }
        
        // when
        syncMOC.performGroupedBlockAndWait {
            guard let request = self.sut.nextRequestIfAllowed() else { return XCTFail() }
            request.complete(with: ZMTransportResponse(payload: nil, httpStatus: 201, transportSessionError: nil))
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNil(label.modifiedKeys)
        }
    }
    
    func testThatItDeletesLabelMarkedForDeletion_AfterSuccessfullyUploadingLabels() {
        var label: Label!
        
        // given
        syncMOC.performGroupedBlockAndWait {
            label = Label.insertNewObject(in: self.syncMOC)
            label.markForDeletion()
            label.modifiedKeys = Set(["markedForDeletion"])
            self.sut.objectsDidChange(Set([label]))
        }
        
        // when
        syncMOC.performGroupedBlockAndWait {
            guard let request = self.sut.nextRequestIfAllowed() else { return XCTFail() }
            request.complete(with: ZMTransportResponse(payload: nil, httpStatus: 201, transportSessionError: nil))
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertTrue(label.isZombieObject)
        }
    }
    
}
