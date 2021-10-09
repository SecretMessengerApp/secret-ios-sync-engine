//


import Foundation
@testable import WireSyncEngine

class CallParticipantsSnapshotTests : MessagingTest {

    var mockWireCallCenterV3 : WireCallCenterV3Mock!
    var mockFlowManager : FlowManagerMock!

    override func setUp() {
        super.setUp()
        mockFlowManager = FlowManagerMock()
        mockWireCallCenterV3 = WireCallCenterV3Mock(userId: UUID(), clientId: "foo", uiMOC: uiMOC, flowManager: mockFlowManager, transport: WireCallCenterTransportMock())
    }
    
    override func tearDown() {
        mockFlowManager = nil
        mockWireCallCenterV3 = nil
        super.tearDown()
    }

    func testThatItDoesNotCrashWhenInitializedWithDuplicateCallMembers(){
        // given
        let userId = UUID()
        let callMember1 = AVSCallMember(userId: userId, audioEstablished: true)
        let callMember2 = AVSCallMember(userId: userId, audioEstablished: false)

        // when
        let sut = WireSyncEngine.CallParticipantsSnapshot(conversationId: UUID(),
                                                          members: [callMember1, callMember2],
                                                          callCenter: mockWireCallCenterV3)
        
        // then
        // it does not crash and
        XCTAssertEqual(sut.members.array.count, 1)
        if let first = sut.members.array.first {
            XCTAssertTrue(first.audioEstablished)
        }
    }
    
    func testThatItDoesNotCrashWhenUpdatedWithDuplicateCallMembers(){
        // given
        let userId = UUID()
        let callMember1 = AVSCallMember(userId: userId, audioEstablished: true)
        let callMember2 = AVSCallMember(userId: userId, audioEstablished: false)
        let sut = WireSyncEngine.CallParticipantsSnapshot(conversationId: UUID(),
                                                          members: [],
                                                          callCenter: mockWireCallCenterV3)

        // when
        sut.callParticipantsChanged(participants: [callMember1, callMember2])
        
        // then
        // it does not crash and
        XCTAssertEqual(sut.members.array.count, 1)
        if let first = sut.members.array.first {
            XCTAssertTrue(first.audioEstablished)
        }
    }
    
    func testThatItKeepsTheMemberWithAudioEstablished(){
        // given
        let userId = UUID()
        let callMember1 = AVSCallMember(userId: userId, audioEstablished: false)
        let callMember2 = AVSCallMember(userId: userId, audioEstablished: true)
        let sut = WireSyncEngine.CallParticipantsSnapshot(conversationId: UUID(),
                                                          members: [],
                                                          callCenter: mockWireCallCenterV3)
        
        // when
        sut.callParticipantsChanged(participants: [callMember1, callMember2])
        
        // then
        // it does not crash and
        XCTAssertEqual(sut.members.array.count, 1)
        if let first = sut.members.array.first {
            XCTAssertTrue(first.audioEstablished)
        }
    }

    func testThatItTakesTheWorstNetworkQualityFromParticipants() {
        // given
        let normalQuality = AVSCallMember(userId: UUID(), audioEstablished: true, videoState: .started, networkQuality: .normal)
        let mediumQuality = AVSCallMember(userId: UUID(), audioEstablished: true, videoState: .started, networkQuality: .medium)
        let poorQuality = AVSCallMember(userId: UUID(), audioEstablished: true, videoState: .started, networkQuality: .poor)

        let sut = WireSyncEngine.CallParticipantsSnapshot(conversationId: UUID(),
                                                          members: [],
                                                          callCenter: mockWireCallCenterV3)
        XCTAssertEqual(sut.networkQuality, .normal)

        // when
        sut.callParticipantsChanged(participants: [normalQuality])
        // then
        XCTAssertEqual(sut.networkQuality, .normal)

        // when
        sut.callParticipantsChanged(participants: [mediumQuality, normalQuality])
        // then
        XCTAssertEqual(sut.networkQuality, .medium)

        // when
        sut.callParticipantsChanged(participants: [poorQuality, normalQuality])
        // then
        XCTAssertEqual(sut.networkQuality, .poor)

        // when
        sut.callParticipantsChanged(participants: [mediumQuality, poorQuality])
        // then
        XCTAssertEqual(sut.networkQuality, .poor)
    }

    func testThatItUpdatesNetworkQualityWhenItChangesForParticipant() {
        // given
        let callMember1 = AVSCallMember(userId: UUID(), audioEstablished: true, networkQuality: .normal)
        let callMember2 = AVSCallMember(userId: UUID(), audioEstablished: true, networkQuality: .normal)
        let sut = WireSyncEngine.CallParticipantsSnapshot(conversationId: UUID(),
                                                          members: [callMember1, callMember2],
                                                          callCenter: mockWireCallCenterV3)
        XCTAssertEqual(sut.networkQuality, .normal)

        // when
        sut.callParticpantNetworkQualityChanged(userId: callMember1.remoteId, networkQuality: .medium)

        // then
        XCTAssertEqual(sut.networkQuality, .medium)

        // when
        sut.callParticpantNetworkQualityChanged(userId: callMember2.remoteId, networkQuality: .poor)

        // then
        XCTAssertEqual(sut.networkQuality, .poor)

        // when
        sut.callParticpantNetworkQualityChanged(userId: callMember1.remoteId, networkQuality: .normal)
        sut.callParticpantNetworkQualityChanged(userId: callMember2.remoteId, networkQuality: .normal)

        // then
        XCTAssertEqual(sut.networkQuality, .normal)
    }
}
