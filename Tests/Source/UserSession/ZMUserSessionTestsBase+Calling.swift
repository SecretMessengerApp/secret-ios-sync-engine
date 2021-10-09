//

import Foundation

import XCTest
@testable import WireSyncEngine

extension ZMUserSessionTestsBase {
    
    @objc
    public func createCallCenter() -> WireCallCenterV3Mock {
        let selfUser = ZMUser.selfUser(in: self.syncMOC)
        return WireCallCenterV3Factory.callCenter(withUserId: selfUser.remoteIdentifier!, clientId: selfUser.selfClient()!.remoteIdentifier!, uiMOC: uiMOC, flowManager: FlowManagerMock(), transport: WireCallCenterTransportMock()) as! WireCallCenterV3Mock
    }
    
    @objc
    public func simulateIncomingCall(fromUser user: ZMUser, conversation: ZMConversation) {
        guard let callCenter = user.managedObjectContext?.zm_callCenter as? WireCallCenterV3Mock else { XCTFail(); return }
        callCenter.setMockCallState(.incoming(video: false, shouldRing: true, degraded: false), conversationId: conversation.remoteIdentifier!, callerId: user.remoteIdentifier, isVideo: false)
    }
    
}
