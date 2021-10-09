//

import Foundation
@testable import WireSyncEngine

class CallStateObserverTests : MessagingTest {
    
    var sut : CallStateObserver!
    var sender : ZMUser!
    var senderUI : ZMUser!
    var receiver : ZMUser!
    var conversation : ZMConversation!
    var conversationUI : ZMConversation!
    var localNotificationDispatcher : LocalNotificationDispatcher!
    var notificationCenter : UserNotificationCenterMock!
    var mockCallCenter : WireCallCenterV3Mock?
    
    override func setUp() {
        super.setUp()
        
        self.mockUserSession.operationStatus.isInBackground = true

        syncMOC.performGroupedBlockAndWait {
            let sender = ZMUser.insertNewObject(in: self.syncMOC)
            sender.name = "Sender"
            sender.remoteIdentifier = UUID()
            
            self.sender = sender
            
            let receiver = ZMUser.insertNewObject(in: self.syncMOC)
            receiver.name = "Receiver"
            receiver.remoteIdentifier = UUID()
            
            self.receiver = receiver
            
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .oneOnOne
            conversation.remoteIdentifier = UUID()
            conversation.internalAddParticipants([sender])
            conversation.internalAddParticipants([receiver])
            conversation.userDefinedName = "Main"
            
            self.conversation = conversation
            
            ZMUser.selfUser(in: self.syncMOC).remoteIdentifier = UUID()

            self.syncMOC.saveOrRollback()
            
            self.localNotificationDispatcher = LocalNotificationDispatcher(in: self.syncMOC)
            
            self.notificationCenter = UserNotificationCenterMock()
            self.localNotificationDispatcher.notificationCenter = self.notificationCenter
        }

        senderUI = uiMOC.object(with: sender.objectID) as? ZMUser
        conversationUI = uiMOC.object(with: conversation.objectID) as? ZMConversation
        sut = CallStateObserver(localNotificationDispatcher: localNotificationDispatcher, userSession: mockUserSession)
        uiMOC.zm_callCenter = mockCallCenter
    }
    
    override func tearDown() {
        localNotificationDispatcher.tearDown()
        
        sut = nil
        sender = nil
        receiver = nil
        conversation = nil
        localNotificationDispatcher = nil
        notificationCenter = nil
        mockCallCenter = nil
        
        super.tearDown()
    }
    
    func testThatInstanceDoesntHaveRetainCycles() {
        var instance: CallStateObserver? = CallStateObserver(localNotificationDispatcher: localNotificationDispatcher, userSession: mockUserSession)
        weak var weakInstance = instance
        instance = nil
        XCTAssertNil(weakInstance)
    }
    
    func testThatMissedCallMessageIsAppendedForCanceledCallByReceiver() {

        // when
        let firstCallState: CallState = .incoming(video: false, shouldRing: false, degraded: false)
        sut.callCenterDidChange(callState: firstCallState, conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        sut.callCenterDidChange(callState: .terminating(reason: .canceled), conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: firstCallState)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        if let message =  conversationUI.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(message.systemMessageType, .missedCall)
            XCTAssertFalse(message.relevantForConversationStatus)
            XCTAssertEqual(message.sender, senderUI)
        } else {
            XCTFail()
        }
    }
    
    func testThatMissedCallMessageIsAppendedForCanceledCallBySender() {
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: false, degraded: false), conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        sut.callCenterDidChange(callState: .terminating(reason: .canceled), conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        self.syncMOC.performGroupedBlockAndWait {
            // then
            if let message = self.conversationUI.lastMessage as? ZMSystemMessage {
                XCTAssertEqual(message.systemMessageType, .missedCall)
                XCTAssertTrue(message.relevantForConversationStatus)
                XCTAssertEqual(message.sender, self.senderUI)
            } else {
                XCTFail()
            }
        }
    }
    
    func testThatMissedCallMessageIsNotAppendedForCallsOtherCallStates() {
        
        // given
        let ignoredCallStates : [CallState] = [.terminating(reason: .anweredElsewhere),
                                               .terminating(reason: .lostMedia),
                                               .terminating(reason: .internalError),
                                               .terminating(reason: .unknown),
                                               .incoming(video: true, shouldRing: false, degraded: false),
                                               .incoming(video: false, shouldRing: false, degraded: false),
                                               .incoming(video: true, shouldRing: true, degraded: false),
                                               .incoming(video: false, shouldRing: true, degraded: false),
                                               .answered(degraded: false),
                                               .established,
                                               .outgoing(degraded: false)]
        
        // when
        for callState in ignoredCallStates {
            sut.callCenterDidChange(callState: callState, conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversationUI.allMessages.count, 0)
    }
    
    func testThatMissedCallMessageIsAppendedForMissedCalls() {
        
        // given when
        sut.callCenterMissedCall(conversation: conversationUI, caller: senderUI, timestamp: Date(), video: false)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        if let message =  conversationUI.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(message.systemMessageType, .missedCall)
            XCTAssertTrue(message.relevantForConversationStatus)
            XCTAssertEqual(message.sender, senderUI)
        } else {
            XCTFail()
        }
    }
    
    func testThatMissedCallsAreForwardedToTheNotificationDispatcher() {
        // given when
        sut.callCenterMissedCall(conversation: conversationUI, caller: senderUI, timestamp: Date(), video: false)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(notificationCenter.scheduledRequests.count, 1)
    }
    
    func testIncomingCallsInUnfetchedConversationAreForwaredToTheNotificationDispatcher_whenCallStyleIsCallkit() {
        // given
        mockCallNotificationStyle = .callKit
        conversationUI.conversationType = .invalid
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversationUI, caller: senderUI, timestamp: Date(), previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(notificationCenter.scheduledRequests.count, 1)
    }
    
    func testThatIncomingCallsInMutedConversationAreForwardedToTheNotificationDispatcher_whenCallStyleIsCallkit() {
        // given
        mockCallNotificationStyle = .callKit
        conversationUI.mutedMessageTypes = .regular
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(notificationCenter.scheduledRequests.count, 1)
    }
    
    func testIncomingCallsInUnfetchedConversationAreForwaredToTheNotificationDispatcher_whenCallStyleIsPushNotification() {
        // given
        mockCallNotificationStyle = .pushNotifications
        conversationUI.conversationType = .invalid
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversationUI, caller: senderUI, timestamp: Date(), previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(notificationCenter.scheduledRequests.count, 1)
    }
    
    func testThatIncomingCallsAreForwardedToTheNotificationDispatcher_whenCallStyleIsPushNotification() {
        // given
        mockCallNotificationStyle = .pushNotifications
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(notificationCenter.scheduledRequests.count, 1)
    }
    
    func testThatWeSendNotificationWhenCallIsEstablished() {
        // given
        mockCallCenter = WireCallCenterV3Mock(userId: UUID.create(), clientId: "1234567", uiMOC: uiMOC, flowManager: FlowManagerMock(), transport: WireCallCenterTransportMock())
        mockCallCenter?.setMockCallState(.established, conversationId: conversation.remoteIdentifier!, callerId: mockCallCenter!.selfUserId, isVideo: false)
        mockUserSession.managedObjectContext.zm_callCenter = mockCallCenter
        
        // expect
        expectation(forNotification: CallStateObserver.CallInProgressNotification, object: nil) { (_) -> Bool in
            return true
        }
        
        // when
        sut.callCenterDidChange(callState: .established, conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatWeSendNotificationWhenCallHasEstablishedDataChannel() {
        // given
        mockCallCenter = WireCallCenterV3Mock(userId: UUID.create(), clientId: "1234567", uiMOC: uiMOC, flowManager: FlowManagerMock(), transport: WireCallCenterTransportMock())
        mockCallCenter?.setMockCallState(.establishedDataChannel, conversationId: conversation.remoteIdentifier!, callerId: mockCallCenter!.selfUserId, isVideo: false)
        mockUserSession.managedObjectContext.zm_callCenter = mockCallCenter
        
        // expect
        expectation(forNotification: CallStateObserver.CallInProgressNotification, object: nil) { (_) -> Bool in
            return true
        }
        
        // when
        sut.callCenterDidChange(callState: .establishedDataChannel, conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
        
    func testThatWeSendNotificationWhenCallTerminates() {
        // given
        mockCallCenter = WireCallCenterV3Mock(userId: UUID.create(), clientId: "1234567", uiMOC: uiMOC, flowManager: FlowManagerMock(), transport: WireCallCenterTransportMock())
        mockCallCenter?.setMockCallState(.established, conversationId: conversation.remoteIdentifier!, callerId: mockCallCenter!.selfUserId, isVideo: false)
        mockUserSession.managedObjectContext.zm_callCenter = mockCallCenter
        sut.callCenterDidChange(callState: .established, conversation: conversationUI, caller: senderUI, timestamp: Date(), previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // expect
        expectation(forNotification: CallStateObserver.CallInProgressNotification, object: nil) { (note) -> Bool in
            if let open = note.userInfo?[CallStateObserver.CallInProgressKey] as? Bool, open == false {
                return true
            } else {
                return false
            }
        }
        
        // when
        mockCallCenter?.removeMockActiveCalls()
        sut.callCenterDidChange(callState: .none, conversation: conversationUI, caller: senderUI, timestamp: Date(), previousCallState: nil)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        
        // tear down
        mockCallCenter = nil
    }
    
    func testThatMissedCallMessageAndNotificationIsAppendedForGroupCallNotJoined() {
        
        self.syncMOC.performGroupedBlockAndWait {
            // given
            self.conversation.conversationType = .group
            self.syncMOC.saveOrRollback()
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: false, degraded: false), conversation: self.conversationUI, caller: self.senderUI, timestamp: nil, previousCallState: nil)
        self.sut.callCenterDidChange(callState: .terminating(reason: .normal), conversation: self.conversationUI, caller: self.senderUI, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(conversationUI.allMessages.count, 1)
        XCTAssertEqual(notificationCenter.scheduledRequests.count, 1)
    }

    func testThatMissedCallNotificationIsNotForwardedForGroupCallAnsweredElsewhere() {
        // given
        self.syncMOC.performGroupedBlockAndWait {
            self.conversation.conversationType = .group
            self.syncMOC.saveOrRollback()
        }
        
        // when
        self.sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: false, degraded: false), conversation: conversationUI, caller: senderUI, timestamp: nil, previousCallState: nil)
        self.sut.callCenterDidChange(callState: .terminating(reason: .anweredElsewhere), conversation: conversationUI, caller: self.senderUI, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(notificationCenter.scheduledRequests.count, 0)
    }
    
    func testThatClearedConversationsGetsUnarchivedForIncomingCalls() {
        // given
        syncMOC.performGroupedBlock {
            self.conversation.lastServerTimeStamp = Date()
            self.conversation.append(text: "test")
            self.conversation.clearMessageHistory()
            XCTAssert(self.conversation.isArchived)
            XCTAssertNotNil(self.conversation.clearedTimeStamp)
            self.syncMOC.saveOrRollback()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.sut.callCenterDidChange(
            callState: .incoming(video: false, shouldRing: true, degraded: false),
            conversation: self.conversationUI,
            caller: self.senderUI,
            timestamp: nil,
            previousCallState: nil
        )
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        uiMOC.refreshAllObjects()
        
        // then
        XCTAssertFalse(conversationUI.isArchived)
    }
    
    func testThatArchivedConversationsGetsUnarchivedForIncomingCalls() {
        // given
        syncMOC.performGroupedBlock {
            self.conversation.lastServerTimeStamp = Date()
            self.conversation.isArchived = true
            XCTAssert(self.conversation.isArchived)
            XCTAssertNil(self.conversation.clearedTimeStamp)
            self.syncMOC.saveOrRollback()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.sut.callCenterDidChange(
            callState: .incoming(video: false, shouldRing: true, degraded: false),
            conversation: self.conversationUI,
            caller: self.senderUI,
            timestamp: nil,
            previousCallState: nil
        )
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        uiMOC.refreshAllObjects()
        
        // then
        XCTAssertFalse(conversationUI.isArchived)
    }
    
    func testThatArchivedAndMutedConversationsDoesNotGetUnarchivedForIncomingCalls() {
        // given
        syncMOC.performGroupedBlock {
            self.conversation.lastServerTimeStamp = Date()
            self.conversation.isArchived = true
            self.conversation.mutedMessageTypes = .all
            XCTAssert(self.conversation.isArchived)
            XCTAssertEqual(self.conversation.mutedMessageTypes, .all)
            XCTAssertNil(self.conversation.clearedTimeStamp)
            self.syncMOC.saveOrRollback()
        }
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        
        // when
        self.sut.callCenterDidChange(
            callState: .incoming(video: false, shouldRing: true, degraded: false),
            conversation: self.conversationUI,
            caller: self.senderUI,
            timestamp: nil,
            previousCallState: nil
        )
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // Then
        XCTAssert(conversationUI.isArchived)
        XCTAssertEqual(conversationUI.mutedMessageTypes, .all)
    }
    
    func testThatSilencedUnarchivedConversationsGetUpdatedForIncomingCalls() {
        // given
        var otherConvo: ZMConversation?
        let startDate = Date(timeIntervalSinceReferenceDate: 12345678)
        
        syncMOC.performGroupedBlock {
            self.conversation.mutedMessageTypes = .all
            self.conversation.isArchived = false
            self.conversation.lastServerTimeStamp = Date()
            self.conversation.lastReadServerTimeStamp = self.conversation.lastServerTimeStamp
            self.conversation.remoteIdentifier = .create()
            self.conversation.lastModifiedDate = startDate
            
            XCTAssertEqual(self.conversation.mutedMessageTypes, .all)
            XCTAssertFalse(self.conversation.isArchived)
            
            otherConvo = ZMConversation.insertNewObject(in: self.syncMOC)
            otherConvo?.conversationType = .oneOnOne
            otherConvo?.remoteIdentifier = UUID()
            otherConvo?.internalAddParticipants([self.sender])
            otherConvo?.internalAddParticipants([self.receiver])
            otherConvo?.userDefinedName = "Other"
            otherConvo?.lastServerTimeStamp = Date()
            otherConvo?.lastModifiedDate = startDate.addingTimeInterval(500)
            
            self.syncMOC.saveOrRollback()
        }
        
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // Current situation:
        // > "Other"
        // > "Main"             (Muted)
        
        let list = ZMConversation.conversationsExcludingArchived(in: syncMOC)
        
        if let first = list.firstObject as? ZMConversation,
            let last = list.lastObject as? ZMConversation {
            XCTAssertEqual(first, otherConvo!)
            XCTAssertEqual(last, self.conversation)
        } else {
            XCTFail()
        }
        
        // when
        self.sut.callCenterDidChange(
            callState: .incoming(video: false, shouldRing: true, degraded: false),
            conversation: self.conversationUI,
            caller: self.senderUI,
            timestamp: Date(),
            previousCallState: nil
        )
        
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        list.resort()
    
        // Then
        
        // Current situation:
        // > "Main"     (JOIN)  (Muted)
        // > "Other"
        
        if let first = list.firstObject as? ZMConversation,
            let last = list.lastObject as? ZMConversation {
            XCTAssertEqual(first, self.conversation)
            XCTAssertEqual(last, otherConvo!)
        } else {
            XCTFail()
        }
    }

}
