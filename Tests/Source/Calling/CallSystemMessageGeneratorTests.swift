//

import Foundation
@testable import WireSyncEngine

class CallSystemMessageGeneratorTests : MessagingTest {

    var sut : WireSyncEngine.CallSystemMessageGenerator!
    var mockWireCallCenterV3 : WireCallCenterV3Mock!
    var selfUserID : UUID!
    var clientID: String!
    var conversation : ZMConversation!
    var user : ZMUser!
    var selfUser : ZMUser!
    
    override func setUp() {
        super.setUp()
        conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.conversationType = .group
        conversation.remoteIdentifier = UUID()
        
        user = ZMUser.insertNewObject(in: uiMOC)
        user.remoteIdentifier = UUID()
        user.name = "Hans"
        
        selfUser = ZMUser.selfUser(in: uiMOC)
        selfUser.remoteIdentifier = UUID()
        selfUserID = selfUser.remoteIdentifier
        clientID = "foo"
        
        sut = WireSyncEngine.CallSystemMessageGenerator()
        mockWireCallCenterV3 = WireCallCenterV3Mock(userId: selfUserID, clientId: clientID, uiMOC: uiMOC, flowManager: FlowManagerMock(), transport: WireCallCenterTransportMock())
    }
    
    override func tearDown() {
        sut = nil
        selfUserID = nil
        clientID = nil
        selfUser = nil
        conversation = nil
        user = nil
        super.tearDown()
        mockWireCallCenterV3 = nil
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
    
    func testThatItAppendsPerformedCallSystemMessage_AnsweredOutgoingCall(){
        // given
        let messageCount = conversation.allMessages.count
        
        // when
        let msg1 = sut.appendSystemMessageIfNeeded(callState: .outgoing(degraded: false), conversation: conversation, caller: selfUser, timestamp: nil, previousCallState: nil)
        let msg2 = sut.appendSystemMessageIfNeeded(callState: .established, conversation: conversation, caller: selfUser, timestamp: nil, previousCallState: nil)
        let msg3 = sut.appendSystemMessageIfNeeded(callState: .terminating(reason: .canceled), conversation: conversation, caller: selfUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(conversation.allMessages.count, messageCount+1)
        XCTAssertNil(msg1)
        XCTAssertNil(msg2)
        if let message = conversation.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(message, msg3)
            XCTAssertEqual(message.systemMessageType, .performedCall)
            XCTAssertTrue(message.users.contains(selfUser))
        } else {
            XCTFail("No system message inserted")
        }
    }
    
    func testThatItAppendsPerformedCallSystemMessage_AnsweredIncomingCall(){
        // given
        let messageCount = conversation.allMessages.count
        
        // when
        let msg1 = sut.appendSystemMessageIfNeeded(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversation, caller: user, timestamp: nil, previousCallState: nil)
        let msg2 = sut.appendSystemMessageIfNeeded(callState: .established , conversation: conversation, caller: user, timestamp: nil, previousCallState: nil)
        let msg3 = sut.appendSystemMessageIfNeeded(callState: .terminating(reason: .canceled), conversation: conversation, caller: user, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(conversation.allMessages.count, messageCount+1)
        XCTAssertNil(msg1)
        XCTAssertNil(msg2)
        if let message = conversation.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(message, msg3)
            XCTAssertEqual(message.systemMessageType, .performedCall)
            XCTAssertTrue(message.users.contains(user))
        } else {
            XCTFail("No system message inserted")
        }
    }
    
    func testThatItAppendsPerformedCallSystemMessage_UnansweredIncomingCallFromSelfuser(){
        // given
        let messageCount = conversation.allMessages.count
        
        // when
        let msg1 = sut.appendSystemMessageIfNeeded(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversation, caller: selfUser, timestamp: nil, previousCallState: nil)
        let msg2 = sut.appendSystemMessageIfNeeded(callState: .terminating(reason: .canceled), conversation: conversation, caller: selfUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(conversation.allMessages.count, messageCount+1)
        XCTAssertNil(msg1)
        if let message = conversation.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(message, msg2)
            XCTAssertEqual(message.systemMessageType, .performedCall)
            XCTAssertTrue(message.users.contains(selfUser))
        } else {
            XCTFail("No system message inserted")
        }
    }
    
    func testThatItAppendsMissedCallSystemMessage_UnansweredIncomingCall(){
        // given
        let messageCount = conversation.allMessages.count
        
        // when
        let msg1 =  sut.appendSystemMessageIfNeeded(callState: .incoming(video:false, shouldRing: true, degraded: false), conversation: conversation, caller: user, timestamp: nil, previousCallState: nil)
        var msg2 : ZMSystemMessage?
        self.performIgnoringZMLogError { 
            msg2 = self.sut.appendSystemMessageIfNeeded(callState: .terminating(reason: .canceled), conversation: self.conversation, caller: self.user, timestamp: nil, previousCallState: nil)
        }

        // then
        XCTAssertEqual(conversation.allMessages.count, messageCount+1)
        XCTAssertNil(msg1)
        if let message = conversation.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(message, msg2)
            XCTAssertEqual(message.systemMessageType, .missedCall)
            XCTAssertTrue(message.users.contains(user))
        } else {
            XCTFail("No system message inserted")
        }
    }
}
