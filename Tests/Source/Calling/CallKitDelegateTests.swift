//

import Foundation
import WireDataModel
import Intents
import CallKit
import OCMock

@testable import WireSyncEngine

class MockSessionManager : NSObject, WireSyncEngine.SessionManagerType {

    static let accountManagerURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MockSessionManager.accounts")
    
    var foregroundNotificationResponder: ForegroundNotificationResponder? = nil
    var callKitDelegate: WireSyncEngine.CallKitDelegate? = nil
    var callNotificationStyle: CallNotificationStyle = .pushNotifications
    var accountManager: AccountManager = AccountManager(sharedDirectory: accountManagerURL)
    var backgroundUserSessions: [UUID : ZMUserSession] = [:]
    
    var mockUserSession : ZMUserSession? = nil
    func withSession(for account: Account, perform completion: @escaping (ZMUserSession) -> ()) {
        if let userSession = mockUserSession {
            completion(userSession)
        }
    }
    
    var lastRequestToShowMessage: (ZMUserSession, ZMConversation, ZMConversationMessage)?
    var lastRequestToShowConversation: (ZMUserSession, ZMConversation)?
    var lastRequestToShowConversationsList: ZMUserSession?
    var lastRequestToShowUserProfile: UserType?
    var lastRequestToShowConnectionRequest: UUID?

    func showConversation(_ conversation: ZMConversation, at message: ZMConversationMessage?, in session: ZMUserSession) {
        if let message = message {
            lastRequestToShowMessage = (session, conversation, message)
        } else {
            lastRequestToShowConversation = (session, conversation)
        }
    }
    
    func showConversationList(in session: ZMUserSession) {
        lastRequestToShowConversationsList = session
    }

    func showUserProfile(user: UserType) {
        lastRequestToShowUserProfile = user
    }

    func showConnectionRequest(userId: UUID) {
        lastRequestToShowConnectionRequest = userId
    }


    @objc public var updatePushTokenCalled = false
    func updatePushToken(for session: ZMUserSession) {
        updatePushTokenCalled = true
    }

    func updateAppIconBadge(accountID: UUID, unreadCount: Int) {
        // no-op
    }
    
    func configureUserNotifications() {
        // no-op
    }

    func update(credentials: ZMCredentials) -> Bool {
        return false
    }
    
    func checkJailbreakIfNeeded() -> Bool {
        return false
    }
    
    
}

class MockCallKitProvider: CXProvider {

    public var timesSetDelegateCalled: Int = 0
    override func setDelegate(_ delegate: CXProviderDelegate?, queue: DispatchQueue?) {
        timesSetDelegateCalled += 1
    }
    
    public var timesReportNewIncomingCallCalled: Int = 0
    public override func reportNewIncomingCall(with UUID: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void) {
        timesReportNewIncomingCallCalled += 1
    }
    
    public var timesReportCallUpdatedCalled: Int = 0
    public override func reportCall(with UUID: UUID, updated update: CXCallUpdate) {
        timesReportCallUpdatedCalled += 1
    }
    
    public var timesReportCallEndedAtCalled: Int = 0
    public var lastEndedReason: CXCallEndedReason = .answeredElsewhere
    public var lastEndedDate: Date? = nil
    override func reportCall(with UUID: UUID, endedAt dateEnded: Date?, reason endedReason: CXCallEndedReason) {
        timesReportCallEndedAtCalled += 1
        lastEndedReason = endedReason
        lastEndedDate = dateEnded
    }
    
    public var timesReportOutgoingCallConnectedAtCalled: Int = 0
    override func reportOutgoingCall(with UUID: UUID, connectedAt dateConnected: Date?) {
        timesReportOutgoingCallConnectedAtCalled += 1
    }
    
    public var timesReportOutgoingCallStartedConnectingCalled: Int = 0
    override func reportOutgoingCall(with UUID: UUID, startedConnectingAt dateStartedConnecting: Date?) {
        timesReportOutgoingCallStartedConnectingCalled += 1
    }
    
    public var isInvalidated : Bool = false
    override func invalidate() {
        isInvalidated = true
    }

}

class MockCallObserver : CXCallObserver {
    
    public var mockCalls : [CXCall] = []
    
    override var calls: [CXCall] {
        return mockCalls
    }
    
}

class MockCallKitCallController: CXCallController {
    
    public override var callObserver: CXCallObserver {
        return mockCallObserver
    }
    
    public var mockTransactionErrorCode : CXErrorCodeRequestTransactionError?
    public var mockErrorCount : Int = 0
    public var timesRequestTransactionCalled: Int = 0
    public var requestedTransactions: [CXTransaction] = []
    public let mockCallObserver = MockCallObserver()
    
    public override func request(_ transaction: CXTransaction, completion: @escaping (Error?) -> Void) {
        timesRequestTransactionCalled = timesRequestTransactionCalled + 1
        requestedTransactions.append(transaction)
        if mockErrorCount >= 1 {
            mockErrorCount = mockErrorCount-1
            completion(mockTransactionErrorCode)
        } else {
            completion(.none)
        }
    }
}

class MockCallAnswerAction : CXAnswerCallAction {
    
    var isFulfilled : Bool = false
    var hasFailed : Bool = false
    
    override func fulfill(withDateConnected dateConnected: Date) {
        isFulfilled = true
    }
    
    override func fail() {
        hasFailed = true
    }
    
}

class MockStartCallAction : CXStartCallAction {
    
    var isFulfilled : Bool = false
    var hasFailed : Bool = false
    
    override func fulfill() {
        isFulfilled = true
    }
    
    override func fail() {
        hasFailed = true
    }
    
}

class MockProvider : CXProvider {
    
    var connectingCalls : Set<UUID> = Set()
    var connectedCalls : Set<UUID> = Set()
    
    convenience init(foo: Bool) {
        self.init(configuration: CXProviderConfiguration(localizedName: "test"))
    }
    
    override func reportOutgoingCall(with UUID: UUID, startedConnectingAt dateStartedConnecting: Date?) {
        connectingCalls.insert(UUID)
    }
    
    override func reportOutgoingCall(with UUID: UUID, connectedAt dateConnected: Date?) {
        connectedCalls.insert(UUID)
    }
    
}

class CallKitDelegateTest: MessagingTest {
    var sut: WireSyncEngine.CallKitDelegate!
    var callKitProvider: MockCallKitProvider!
    var callKitController: MockCallKitCallController!
    var mockWireCallCenterV3 : WireCallCenterV3Mock!
    var mockSessionManager :  MockSessionManager!
    
    func otherUser(moc: NSManagedObjectContext) -> ZMUser {
        let otherUser = ZMUser(context: moc)
        otherUser.remoteIdentifier = UUID()
        otherUser.name = "Other Test User"
        
        return otherUser
    }
    
    func createOneOnOneConversation(user: ZMUser) {
        let oneToOne = ZMConversation.insertNewObject(in: self.uiMOC)
        oneToOne.conversationType = .oneOnOne
        oneToOne.remoteIdentifier = UUID()
        
        let connection = ZMConnection.insertNewObject(in: self.uiMOC)
        connection.status = .accepted
        connection.conversation = oneToOne
        connection.to = user
    }
    
    func conversation(type: ZMConversationType = .oneOnOne, moc: NSManagedObjectContext? = .none) -> ZMConversation {
        let moc = moc ?? self.uiMOC
        let conversation = ZMConversation(context: moc)
        conversation.remoteIdentifier = UUID()
        conversation.conversationType = type
        conversation.isSelfAnActiveMember = true
        
        if type == .group {
            conversation.internalAddParticipants([self.otherUser(moc: moc)])
        }
        
        return conversation
    }
    
    override func setUp() {
        super.setUp()
        
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        selfUser.remoteIdentifier = UUID()
        
        let flowManager = FlowManagerMock()
        let configuration = WireSyncEngine.CallKitDelegate.providerConfiguration
        self.callKitProvider = MockCallKitProvider(configuration: configuration)
        self.callKitController = MockCallKitCallController()
        self.mockWireCallCenterV3 = WireCallCenterV3Mock(userId: selfUser.remoteIdentifier!, clientId: "123", uiMOC: uiMOC, flowManager: flowManager, transport: WireCallCenterTransportMock())
        self.mockSessionManager = MockSessionManager()
        
        mockSessionManager.mockUserSession = self.mockUserSession
        mockSessionManager.accountManager.addAndSelect(Account(userName: "Test User", userIdentifier: selfUser.remoteIdentifier!))
        
        self.sut = WireSyncEngine.CallKitDelegate(provider: callKitProvider,
                                                  callController: callKitController,
                                                  sessionManager: mockSessionManager,
                                                  mediaManager: nil)
        
        CallKitDelegateTestsMocking.mockUserSession(self.mockUserSession)
        
        self.uiMOC.zm_callCenter = mockWireCallCenterV3
    }
    
    override func tearDown() {
        self.sut = nil
        self.mockWireCallCenterV3 = nil
        self.mockSessionManager = nil
        
        super.tearDown()
    }
    
    // MARK: Provider configuration
    func testThatItReturnsTheProviderConfiguration() {
        // when
        let configuration = WireSyncEngine.CallKitDelegate.providerConfiguration
        
        // then
        XCTAssertEqual(configuration.supportsVideo, true)
        XCTAssertEqual(configuration.localizedName, "WireSyncEngine Test Host")
        XCTAssertTrue(configuration.supportedHandleTypes.contains(.generic))
    }
    
    func testThatItReturnsDefaultRingSound() {
        // when
        let configuration = WireSyncEngine.CallKitDelegate.providerConfiguration
        
        // then
        XCTAssertEqual(configuration.ringtoneSound, "ringing_from_them_long.caf")
    }
    
    func testThatItReturnsCustomRingSound() {
        defer {
            UserDefaults.standard.removeObject(forKey: "ZMCallSoundName")
        }
        let customSoundName = "harp"
        // given
        UserDefaults.standard.setValue(customSoundName, forKey: "ZMCallSoundName")
        // when
        let configuration = WireSyncEngine.CallKitDelegate.providerConfiguration
        
        // then
        XCTAssertEqual(configuration.ringtoneSound, customSoundName + ".m4a")
    }
    
    func testThatItInvalidatesTheProviderOnDeinit() {
        // given
        sut = WireSyncEngine.CallKitDelegate(provider: callKitProvider,
                                             callController: callKitController,
                                             sessionManager: mockSessionManager,
                                             mediaManager: nil)
        
        // when
        sut = nil
        
        // then
        XCTAssertTrue(callKitProvider.isInvalidated)
    }
    
    // MARK: Reporting Actions
    
    func testThatItReportsTheStartCallRequest() {
        // given
        let selfUser = ZMUser.selfUser(in: uiMOC)
        let user = otherUser(moc: uiMOC)
        createOneOnOneConversation(user: user)
        let conversation = user.oneToOneConversation!
        
        // when
        self.sut.requestJoinCall(in: conversation, video: false)
        
        // then
        XCTAssertEqual(self.callKitProvider.timesReportCallUpdatedCalled, 0)
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXStartCallAction)
        let action = self.callKitController.requestedTransactions.first!.actions.first! as! CXStartCallAction
        
        XCTAssertEqual(action.callUUID, sut.callUUID(for: conversation))
        XCTAssertEqual(action.handle.type, .generic)
        XCTAssertEqual(action.handle.value, "\(selfUser.remoteIdentifier!.transportString())+\(conversation.remoteIdentifier!.transportString())")
    }
    
    func testThatItReportsTheStartCallRequest_groupConversation() {
        // given
        let selfUser = ZMUser.selfUser(in: uiMOC)
        let conversation = self.conversation(type: .group)
        
        // when
        self.sut.requestJoinCall(in: conversation, video: false)
        
        // then
        XCTAssertEqual(self.callKitProvider.timesReportCallUpdatedCalled, 0)
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXStartCallAction)
        
        let action = self.callKitController.requestedTransactions.first!.actions.first! as! CXStartCallAction
        XCTAssertEqual(action.callUUID, sut.callUUID(for: conversation))
        XCTAssertEqual(action.handle.type, .generic)
        XCTAssertEqual(action.handle.value, "\(selfUser.remoteIdentifier!.transportString())+\(conversation.remoteIdentifier!.transportString())")
        XCTAssertFalse(action.isVideo)
    }
    
    func testThatItReportsTheStartCallRequest_Video() {
        // given
        let selfUser = ZMUser.selfUser(in: uiMOC)
        let otherUser = self.otherUser(moc: self.uiMOC)
        createOneOnOneConversation(user: otherUser)
        let conversation = otherUser.oneToOneConversation!
        self.uiMOC.saveOrRollback()
        
        // when
        self.sut.requestJoinCall(in: conversation, video: true)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXStartCallAction)
        let action = self.callKitController.requestedTransactions.first!.actions.first! as! CXStartCallAction
        
        XCTAssertEqual(action.callUUID, sut.callUUID(for: conversation))
        XCTAssertEqual(action.handle.type, .generic)
        XCTAssertEqual(action.handle.value, "\(selfUser.remoteIdentifier!.transportString())+\(conversation.remoteIdentifier!.transportString())")
        XCTAssertTrue(action.isVideo)
    }
    
    func testThatItReportsTheStartCallRequest_CallAlreadyExists() {
        // given
        let otherUser = self.otherUser(moc: self.uiMOC)
        createOneOnOneConversation(user: otherUser)
        let conversation = otherUser.oneToOneConversation!
        self.uiMOC.saveOrRollback()
        
        self.callKitController.mockErrorCount = 1
        let error = NSError(domain: CXErrorDomainRequestTransaction, code: CXErrorCodeRequestTransactionError.Code.callUUIDAlreadyExists.rawValue, userInfo: nil)
        self.callKitController.mockTransactionErrorCode = CXErrorCodeRequestTransactionError(_nsError: error)
        
        // when
        self.sut.requestJoinCall(in: conversation, video: true)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 2)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXStartCallAction)
        XCTAssertTrue(self.callKitController.requestedTransactions.last!.actions.first! is CXAnswerCallAction)

        let action = self.callKitController.requestedTransactions.last!.actions.last! as! CXAnswerCallAction
        XCTAssertEqual(action.callUUID, sut.callUUID(for: conversation))
    }
    
    func testThatItReportsTheAnswerCallRequest_IfThereExistingIncomingCall() {
        // given
        let otherUser = self.otherUser(moc: self.uiMOC)
        createOneOnOneConversation(user: otherUser)
        let conversation = otherUser.oneToOneConversation!
        self.uiMOC.saveOrRollback()

        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        mockWireCallCenterV3.setMockCallState(state, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: false)
        self.sut.callCenterDidChange(callState: state, conversation: conversation, caller: otherUser, timestamp: Date(), previousCallState: nil)
        
        let call = CallKitDelegateTestsMocking.mockCall(with: sut.callUUID(for: conversation)!, outgoing: false)
        self.callKitController.mockCallObserver.mockCalls = [call]
        
        // when
        self.sut.requestJoinCall(in: conversation, video: true)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        
        let action = self.callKitController.requestedTransactions.last!.actions.last! as! CXAnswerCallAction
        XCTAssertEqual(action.callUUID, sut.callUUID(for: conversation))
        
        // teardown
        CallKitDelegateTestsMocking.stopMock(call)
    }
    
    // MARK: Performing Actions
    
    func testThatCallAnswerActionIsFulfilledWhenCallIsEstablished() {
        // given
        let otherUser = self.otherUser(moc: self.uiMOC)
        createOneOnOneConversation(user: otherUser)
        let conversation = otherUser.oneToOneConversation!
        let provider = MockProvider(foo: true)
        sut.reportIncomingCall(from: otherUser, in: conversation, video: false)
        let action = MockCallAnswerAction(call: sut.callUUID(for: conversation)!)
        self.sut.provider(provider, perform: action)
        
        // when
        mockWireCallCenterV3.update(callState: .established, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: false)
        
        // then
        XCTAssertTrue(action.isFulfilled)
    }
    
    func testThatCallAnswerActionIsFulfilledWhenDataChannelIsEstablished() {
        // given
        let otherUser = self.otherUser(moc: self.uiMOC)
        createOneOnOneConversation(user: otherUser)
        let conversation = otherUser.oneToOneConversation!
        let provider = MockProvider(foo: true)
        sut.reportIncomingCall(from: otherUser, in: conversation, video: false)
        let action = MockCallAnswerAction(call: sut.callUUID(for: conversation)!)
        self.sut.provider(provider, perform: action)
        
        // when
        mockWireCallCenterV3.update(callState: .establishedDataChannel, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: false)
        
        // then
        XCTAssertTrue(action.isFulfilled)
    }

    /* Disabled for now, pending furter investigation
    func testThatCallAnswerActionFailWhenCallCantBeJoined() {
        // given
        let otherUser = self.otherUser(moc: self.uiMOC)
        let provider = MockProvider(foo: true)
        let conversation = self.conversation(type: .oneOnOne)
        
        sut.reportIncomingCall(from: otherUser, in: conversation, video: false)
        let action = MockCallAnswerAction(call: sut.callUUID(for: conversation)!)
        self.sut.provider(provider, perform: action)

        // when
        mockWireCallCenterV3.update(callState: .terminating(reason: .lostMedia), conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: false)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        // then
        XCTAssertTrue(action.hasFailed)
    }
     */
    
    func testThatStartCallActionIsFulfilledWhenCallIsJoined() {
        // given
        let provider = MockProvider(foo: true)
        let conversation = self.conversation(type: .oneOnOne)
        sut.requestStartCall(in: conversation, video: false)
        let action = MockStartCallAction(call: sut.callUUID(for: conversation)!, handle: CXHandle(type: CXHandle.HandleType.generic, value: conversation.remoteIdentifier!.transportString()))
        
        // when
        self.sut.provider(provider, perform: action)
        
        // then
        XCTAssertTrue(action.isFulfilled)
    }
    
    func testThatStartCallActionFailWhenCallCantBeStarted() {
        // given
        let provider = MockProvider(foo: true)
        let conversation = self.conversation(type: .oneOnOne)
        
        sut.requestStartCall(in: conversation, video: false)
        let action = MockStartCallAction(call: sut.callUUID(for: conversation)!, handle: CXHandle(type: CXHandle.HandleType.generic, value: conversation.remoteIdentifier!.transportString()))
        mockWireCallCenterV3.startCallShouldFail = true
        
        // when
        self.sut.provider(provider, perform: action)
        
        // then
        XCTAssertTrue(action.hasFailed)
    }
        
    func testThatStartCallActionUpdatesWhenTheCallHasStartedConnecting() {
        // given
        let provider = MockProvider(foo: true)
        let conversation = self.conversation(type: .oneOnOne)
        
        sut.requestStartCall(in: conversation, video: false)
        let callUUID = sut.callUUID(for: conversation)!
        let action = MockStartCallAction(call: callUUID, handle: CXHandle(type: CXHandle.HandleType.generic, value: conversation.remoteIdentifier!.transportString()))
        
        // when
        self.sut.provider(provider, perform: action)
        mockWireCallCenterV3.update(callState: .answered(degraded: false), conversationId: conversation.remoteIdentifier!, callerId: ZMUser.selfUser(in: uiMOC).remoteIdentifier!, isVideo: false)
        
        // then
        XCTAssertTrue(provider.connectingCalls.contains(callUUID))
    }
    
    func testThatStartCallActionUpdatesWhenTheCallHasConnected() {
        // given
        let provider = MockProvider(foo: true)
        let conversation = self.conversation(type: .oneOnOne)
        
        sut.requestStartCall(in: conversation, video: false)
        let callUUID = sut.callUUID(for: conversation)!
        let action = MockStartCallAction(call: callUUID, handle: CXHandle(type: CXHandle.HandleType.generic, value: conversation.remoteIdentifier!.transportString()))
        
        // when
        self.sut.provider(provider, perform: action)
        mockWireCallCenterV3.update(callState: .establishedDataChannel, conversationId: conversation.remoteIdentifier!, callerId: ZMUser.selfUser(in: uiMOC).remoteIdentifier!, isVideo: false)
        
        // then
        XCTAssertTrue(provider.connectedCalls.contains(callUUID))
    }
    
    // MARK: Report end on outgoing call
    
    func testThatItReportsTheEndOfCall() {
        // given
        let conversation = self.conversation(type: .oneOnOne)
        let otherUser = self.otherUser(moc: self.uiMOC)

        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        mockWireCallCenterV3.setMockCallState(state, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier!, isVideo: true)
        self.sut.callCenterDidChange(callState: state, conversation: conversation, caller: otherUser, timestamp: Date(), previousCallState: nil)
        let callUUID = sut.callUUID(for: conversation)!
        
        // when
        self.sut.requestEndCall(in: conversation)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXEndCallAction)
        
        let action = self.callKitController.requestedTransactions.first!.actions.first! as! CXEndCallAction
        XCTAssertEqual(action.callUUID, callUUID)
    }
    
    func testThatItReportsTheEndOfCall_groupConversation() {
        // given
        let conversation = self.conversation(type: .group)
        let otherUser = self.otherUser(moc: self.uiMOC)

        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        mockWireCallCenterV3.setMockCallState(state, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: true)
        self.sut.callCenterDidChange(callState: state, conversation: conversation, caller: otherUser, timestamp: Date(), previousCallState: nil)
        let callUUID = sut.callUUID(for: conversation)
        
        // when
        self.sut.requestEndCall(in: conversation)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXEndCallAction)
        
        let action = self.callKitController.requestedTransactions.first!.actions.first! as! CXEndCallAction
        XCTAssertEqual(action.callUUID, callUUID)
    }
    
    func testThatReportsMutingOfCall() {
        // given
        let conversation = self.conversation(type: .group)
        let otherUser = self.otherUser(moc: self.uiMOC)

        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        mockWireCallCenterV3.setMockCallState(state, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: true)
        self.sut.callCenterDidChange(callState: state, conversation: conversation, caller: otherUser, timestamp: Date(), previousCallState: nil)
        let callUUID = sut.callUUID(for: conversation)
        
        // when
        sut.requestMuteCall(in: conversation, muted: true)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXSetMutedCallAction)
        
        let action = self.callKitController.requestedTransactions.first!.actions.first! as! CXSetMutedCallAction
        XCTAssertEqual(action.callUUID, callUUID)
    }
    
    //  MARK:  Activity & Intents
    
    func userActivityFor(contacts: [INPerson]?, isVideo: Bool = false) -> NSUserActivity {

        let intent: INIntent
        
        if isVideo {
            intent = INStartVideoCallIntent(contacts: contacts)
        }
        else {
            intent = INStartAudioCallIntent(contacts: contacts)
        }
            
        let interaction = INInteraction(intent: intent, response: .none)
        
        let activity = NSUserActivity(activityType: "voip")
        activity.setValue(interaction, forKey: "interaction")
        return activity
    }
    
    func testThatItStartsCallForGroup() {
        // given
        let selfUser = ZMUser.selfUser(in: uiMOC)
        let conversation = self.conversation(type: .group)
        let identifier = "\(selfUser.remoteIdentifier!.transportString())+\(conversation.remoteIdentifier!.transportString())"
        let handle = INPersonHandle(value: identifier, type: .unknown)
        let person = INPerson(personHandle: handle, nameComponents: .none, displayName: .none, image: .none, contactIdentifier: .none, customIdentifier: identifier)
        let activity = self.userActivityFor(contacts: [person])
        
        // when
        _ = sut.continueUserActivity(activity)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 1)
        XCTAssertTrue(self.callKitController.requestedTransactions.first!.actions.first! is CXStartCallAction)
        
        let action = self.callKitController.requestedTransactions.first!.actions.first! as! CXStartCallAction
        XCTAssertEqual(action.callUUID, sut.callUUID(for: conversation))
        XCTAssertFalse(action.isVideo)
    }
    
    func testThatItIgnoresUnknownActivity() {
        // given
        let activity = NSUserActivity(activityType: "random-handoff")
        
        // when
        _ = sut.continueUserActivity(activity)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 0)
    }
    
    func testThatItIgnoresActivityWitoutContacts() {
        // given
        let activity = self.userActivityFor(contacts: [], isVideo: false)
        
        // when
        _ = sut.continueUserActivity(activity)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 0)
    }
    
    func testThatItIgnoresActivityWithManyContacts() {
        // given

        let handle1 = INPersonHandle(value: "+987654321", type: .phoneNumber)
        let person1 = INPerson(personHandle: handle1, nameComponents: .none, displayName: .none, image: .none, contactIdentifier: .none, customIdentifier: .none)

        let handle2 = INPersonHandle(value: "+987654300", type: .phoneNumber)
        let person2 = INPerson(personHandle: handle2, nameComponents: .none, displayName: .none, image: .none, contactIdentifier: .none, customIdentifier: .none)

        let activity = self.userActivityFor(contacts: [person1, person2], isVideo: false)
        
        // when
        _ = sut.continueUserActivity(activity)
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 0)
    }
    
    func testThatItIgnoresActivityWithContactUnknown() {
        // given
        let otherUser = self.otherUser(moc: self.uiMOC)
        createOneOnOneConversation(user: otherUser)
        
        let handle = INPersonHandle(value: "+987654321", type: .phoneNumber)
        let person = INPerson(personHandle: handle, nameComponents: .none, displayName: .none, image: .none, contactIdentifier: .none, customIdentifier: .none)
        
        let activity = self.userActivityFor(contacts: [person], isVideo: false)
        
        // when
        performIgnoringZMLogError {
            _ = self.sut.continueUserActivity(activity)
        }
        
        // then
        XCTAssertEqual(self.callKitController.timesRequestTransactionCalled, 0)
    }
    
    // MARK: Observing call state
    
    func testThatItReportNewIncomingCall_v3_Incoming() {
        // given
        let conversation = self.conversation()
        let otherUser = self.otherUser(moc: self.uiMOC)
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversation, caller: otherUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.timesReportNewIncomingCallCalled, 1)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallConnectedAtCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallStartedConnectingCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportCallEndedAtCalled, 0)
    }
    
    func testThatItIgnoresNewIncomingCall_v3_Incoming_Silenced() {
        // given
        let conversation = self.conversation()
        conversation.mutedMessageTypes = .all
        let otherUser = self.otherUser(moc: self.uiMOC)
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversation, caller: otherUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.timesReportNewIncomingCallCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallConnectedAtCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallStartedConnectingCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportCallEndedAtCalled, 0)
    }
    
    func testThatItIgnoresNewIncomingCall_v3_Unfectched_conversation() {
        // given
        let conversation = self.conversation()
        conversation.needsToBeUpdatedFromBackend = true
        let otherUser = self.otherUser(moc: self.uiMOC)
        
        // when
        sut.callCenterDidChange(callState: .incoming(video: false, shouldRing: true, degraded: false), conversation: conversation, caller: otherUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.timesReportNewIncomingCallCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallConnectedAtCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallStartedConnectingCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportCallEndedAtCalled, 0)
    }
    
    func testThatItReportCallEndedAt_v3_Terminating_normal() {
        // given
        let conversation = self.conversation()
        let otherUser = self.otherUser(moc: self.uiMOC)
        sut.requestStartCall(in: conversation, video: false)
        
        // when
        sut.callCenterDidChange(callState: .terminating(reason: .normal), conversation: conversation, caller: otherUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.timesReportNewIncomingCallCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallConnectedAtCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallStartedConnectingCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportCallEndedAtCalled, 1)
        XCTAssertEqual(self.callKitProvider.lastEndedReason, .remoteEnded)
    }
    
    func testThatItReportCallEndedAt_v3_Terminating_inTheFuture() {
        // given
        let conversation = self.conversation()
        let otherUser = self.otherUser(moc: self.uiMOC)
        sut.requestStartCall(in: conversation, video: false)
        
        // when
        sut.callCenterDidChange(callState: .terminating(reason: .normal), conversation: conversation, caller: otherUser, timestamp: Date(timeIntervalSinceNow: 10000), previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.timesReportNewIncomingCallCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallConnectedAtCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportOutgoingCallStartedConnectingCalled, 0)
        XCTAssertEqual(self.callKitProvider.timesReportCallEndedAtCalled, 1)
        XCTAssertEqual(self.callKitProvider.lastEndedReason, .remoteEnded)
        XCTAssertEqual(Int(self.callKitProvider.lastEndedDate!.timeIntervalSinceNow), 0)
    }
    
    func testThatItReportCallEndedAt_v3_Terminating_lostMedia() {
        // given
        let conversation = self.conversation()
        let otherUser = self.otherUser(moc: self.uiMOC)

        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        mockWireCallCenterV3.setMockCallState(state, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: true)
        self.sut.callCenterDidChange(callState: state, conversation: conversation, caller: otherUser, timestamp: Date(), previousCallState: nil)
        
        // when
        sut.callCenterDidChange(callState: .terminating(reason: .lostMedia), conversation: conversation, caller: otherUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.lastEndedReason, .failed)
    }
    
    func testThatItReportCallEndedAt_v3_Terminating_timeout() {
        // given
        let conversation = self.conversation()
        let otherUser = self.otherUser(moc: self.uiMOC)
        
        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        mockWireCallCenterV3.setMockCallState(state, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: true)
        self.sut.callCenterDidChange(callState: state, conversation: conversation, caller: otherUser, timestamp: Date(), previousCallState: nil)
        
        // when
        sut.callCenterDidChange(callState: .terminating(reason: .timeout), conversation: conversation, caller: otherUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.lastEndedReason, .unanswered)
    }
    
    func testThatItReportCallEndedAt_v3_Terminating_answeredElsewhere() {
        // given
        let conversation = self.conversation()
        let otherUser = self.otherUser(moc: self.uiMOC)

        let state: CallState = .incoming(video: true, shouldRing: true, degraded: false)
        mockWireCallCenterV3.setMockCallState(state, conversationId: conversation.remoteIdentifier!, callerId: otherUser.remoteIdentifier, isVideo: true)
        self.sut.callCenterDidChange(callState: state, conversation: conversation, caller: otherUser, timestamp: Date(), previousCallState: nil)
        
        // when
        sut.callCenterDidChange(callState: .terminating(reason: .anweredElsewhere), conversation: conversation, caller: otherUser, timestamp: nil, previousCallState: nil)
        
        // then
        XCTAssertEqual(self.callKitProvider.lastEndedReason, .answeredElsewhere)
    }
    
}
