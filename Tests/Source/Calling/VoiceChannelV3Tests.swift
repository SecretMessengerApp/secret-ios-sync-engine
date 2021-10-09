//

import Foundation

import Foundation
@testable import WireSyncEngine

class VoiceChannelV3Tests : MessagingTest {
    
    var wireCallCenterMock : WireCallCenterV3Mock? = nil
    var conversation : ZMConversation?
    var sut : VoiceChannelV3!
    
    override func setUp() {
        super.setUp()
        
        let selfUser = ZMUser.selfUser(in: uiMOC)
        selfUser.remoteIdentifier = UUID.create()
        
        let selfClient = createSelfClient()
        
        conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation?.remoteIdentifier = UUID.create()
        
        wireCallCenterMock = WireCallCenterV3Mock(userId: selfUser.remoteIdentifier!, clientId: selfClient.remoteIdentifier!, uiMOC: uiMOC, flowManager: FlowManagerMock(), transport: WireCallCenterTransportMock())
        
        uiMOC.zm_callCenter = wireCallCenterMock
        
        sut = VoiceChannelV3(conversation: conversation!)
    }
    
    override func tearDown() {
        super.tearDown()
        
        wireCallCenterMock = nil
    }
    
    func testThatItStartsACall_whenTheresNotAnIncomingCall() {
        // given
        wireCallCenterMock?.removeMockActiveCalls()
        
        // when
        _ = sut.join(video: false)
        
        // then
        XCTAssertTrue(wireCallCenterMock!.didCallStartCall)
    }
    
    func testThatItAnswers_whenTheresAnIncomingCall() {
        // given
        wireCallCenterMock?.setMockCallState(.incoming(video: false, shouldRing: false, degraded: false), conversationId: conversation!.remoteIdentifier!, callerId: UUID(), isVideo: false)

        // when
        _ = sut.join(video: false)
        
        // then
        XCTAssertTrue(wireCallCenterMock!.didCallAnswerCall)
    }
    
    func testThatItDoesntAnswer_whenTheresAnIncomingDegradedCall() {
        // given
        wireCallCenterMock?.setMockCallState(.incoming(video: false, shouldRing: false, degraded: true), conversationId: conversation!.remoteIdentifier!, callerId: UUID(), isVideo: false)

        // when
        _ = sut.join(video: false)
        
        // then
        XCTAssertFalse(wireCallCenterMock!.didCallAnswerCall)
    }

    func testThatItForwardsNetworkQualityFromCallCenter() {
        // given
        let calledId = UUID()
        wireCallCenterMock?.setMockCallState(.established, conversationId: conversation!.remoteIdentifier!, callerId: calledId, isVideo: false)
        let quality = NetworkQuality.poor
        XCTAssertEqual(sut.networkQuality, .normal)

        // when
        wireCallCenterMock?.handleNetworkQualityChange(conversationId: conversation!.remoteIdentifier!, userId: calledId, quality: quality)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(sut.networkQuality, quality)
    }

}
