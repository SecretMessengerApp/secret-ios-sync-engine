//

import Foundation
@testable import WireSyncEngine

class ZMLocalNotificationTests_CallState : MessagingTest {
    
    var sender : ZMUser!
    var conversation : ZMConversation!
    
    override func setUp() {
        super.setUp()
        
        syncMOC.performGroupedBlockAndWait {
            let sender = ZMUser.insertNewObject(in: self.syncMOC)
            sender.name = "Callie"
            sender.remoteIdentifier = UUID()
            
            self.sender = sender
            
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .oneOnOne
            conversation.remoteIdentifier = UUID()
            conversation.internalAddParticipants([sender])
            
            self.conversation = conversation
            
            ZMUser.selfUser(in: self.syncMOC).remoteIdentifier = UUID()
        }
    }
    
    func note(for callState: CallState) -> ZMLocalNotification? {
        return ZMLocalNotification(callState: callState, conversation: conversation, caller: sender)
    }
    
    func testIncomingAudioCall() {
        
        // given
        let state: CallState = .incoming(video: false, shouldRing: true, degraded: false)
        
        // when
        guard let note = self.note(for: state) else { return XCTFail("Did not create notification") }
        
        // then
        XCTAssertEqual(note.title, "Callie")
        XCTAssertEqual(note.body, "is calling")
        XCTAssertEqual(note.category, WireSyncEngine.PushNotificationCategory.incomingCall.rawValue)
        XCTAssertEqual(note.sound, .call)
    }
    
    func testIncomingAudioCall_WithAvailabilityAway() {
        
        // given
        syncMOC.performGroupedBlockAndWait {
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            selfUser.availability = .away
        }
        
        let state: CallState = .incoming(video: false, shouldRing: true, degraded: false)
        
        // then
        XCTAssertNil(note(for: state))
    }
    
    func testIncomingAudioCall_WithAllMutedConversation() {
        
        // given
        syncMOC.performGroupedBlockAndWait {
            self.conversation.mutedMessageTypes = .all
        }
        
        let state: CallState = .incoming(video: false, shouldRing: true, degraded: false)
        
        // then
        XCTAssertNil(note(for: state))
    }
    
    func testIncomingAudioCall_ShouldRing_False() {
        
        // given
        let state: CallState = .incoming(video: false, shouldRing: false, degraded: false)
        
        // then
        XCTAssertNil(note(for: state))
    }
    
    func testIncomingVideoCall() {
        
        // given
        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        
        // when
        guard let note = self.note(for: state) else { return XCTFail("Did not create notification") }
        
        // then
        XCTAssertEqual(note.title, "Callie")
        XCTAssertEqual(note.body, "is calling with video")
        XCTAssertEqual(note.category, WireSyncEngine.PushNotificationCategory.incomingCall.rawValue)
        XCTAssertEqual(note.sound, .call)
    }
    
    func testIncomingVideoCall_ShouldRing_False() {
        
        // given
        let state: CallState = .incoming(video: true, shouldRing: false, degraded: false)
        
        // then
        XCTAssertNil(note(for: state))
    }
    
    func testCanceledCall() {
        
        // given
        let state: CallState = .terminating(reason: .canceled)
        
        // when
        guard let note = self.note(for: state) else { return XCTFail("Did not create notification") }
        
        // then
        XCTAssertEqual(note.title, "Callie")
        XCTAssertEqual(note.body, "called")
        XCTAssertEqual(note.category, WireSyncEngine.PushNotificationCategory.conversationWithMute.rawValue)
        XCTAssertEqual(note.sound, .newMessage)
    }
    
    func testCallClosedReasonsWhichShouldBeIgnored() {
        
        // given
        let ignoredCallClosedReasons : [CallClosedReason] = [.anweredElsewhere, .normal]
        
        for reason in ignoredCallClosedReasons {
            // when
            let note = self.note(for: .terminating(reason: reason))
            
            // then
            XCTAssertNil(note)
        }
    }
    
    
    func testMissedCall() {
        
        // given
        let state: CallState = .terminating(reason: .timeout)
        
        // when
        guard let note = self.note(for: state) else { return XCTFail("Did not create notification") }
        
        // then
        XCTAssertEqual(note.title, "Callie")
        XCTAssertEqual(note.body, "called")
        XCTAssertEqual(note.category, WireSyncEngine.PushNotificationCategory.missedCall.rawValue)
        XCTAssertEqual(note.sound, .newMessage)
    }
    
    func testMissedCallFromSelfUser() {
        
        // given
        let state: CallState = .terminating(reason: .timeout)
        let caller = ZMUser.selfUser(in: uiMOC)
        caller.name = "SelfUser"
        
        // when
        guard let note = ZMLocalNotification(callState: state, conversation: conversation, caller: caller) else { return XCTFail("Did not create notification") }
        
        // then
        XCTAssertEqual(note.title, "Callie")
        XCTAssertEqual(note.body, "called")
        XCTAssertEqual(note.category, WireSyncEngine.PushNotificationCategory.missedCall.rawValue)
        XCTAssertEqual(note.sound, .newMessage)
    }
    
    func testThatItAddsATitleIfTheUserIsPartOfATeam() {
        self.syncMOC.performGroupedBlockAndWait {
            
            // given
            let team = Team.insertNewObject(in: self.syncMOC)
            team.name = "Wire Amazing Team"
            let user = ZMUser.selfUser(in: self.syncMOC)
            _ = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            self.syncMOC.saveOrRollback()
            
            XCTAssertNotNil(user.team)
            
            let state: CallState = .incoming(video: false, shouldRing: true, degraded: false)
            
            // when
            guard let note = self.note(for: state) else { return XCTFail("Did not create notification") }
            
            // then
            XCTAssertEqual(note.title, "Callie in \(team.name!)")
        }
    }
    
    func testThatItDoesNotAddATitleIfTheUserIsNotPartOfATeam() {
        
        // given
        let state: CallState = .incoming(video: false, shouldRing: true, degraded: false)
        
        // when
        guard let note = self.note(for: state) else { return XCTFail("Did not create notification") }
        
        // then
        XCTAssertEqual(note.title, "Callie")
    }
}

