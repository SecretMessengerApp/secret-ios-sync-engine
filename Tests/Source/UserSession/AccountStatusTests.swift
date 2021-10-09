

@testable import WireSyncEngine

class AccountStatusTests : MessagingTest {

    var sut : AccountStatus!
    
    override func setUp() {
        super.setUp()
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        selfUser.remoteIdentifier = self.userIdentifier
        self.uiMOC.saveOrRollback()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
        
    }
    
    func testThatItRemainsActivatedByDefault() {
        // given
        self.sut = AccountStatus(managedObjectContext: self.uiMOC)
        
        // then
        XCTAssertEqual(self.sut.accountState, AccountState.activated)
    }
    
    func testThatItUpdatesAccountStateWhenRegisteringClient() {
        // given
        self.sut = AccountStatus(managedObjectContext: self.uiMOC)
        
        // when
        PostLoginAuthenticationNotification.notifyClientRegistrationDidSucceed(context: uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(self.sut.accountState, AccountState.newDevice)
    }
    
    func testThatItUpdatesAccountStateWhenCompletingLogin() {
        // given
        self.sut = AccountStatus(managedObjectContext: self.uiMOC)
        
        // when
        sut.didCompleteLogin()
        
        // then
        XCTAssertEqual(self.sut.accountState, AccountState.deactivated)
    }
    
    func testThatItDoesNotAppendAnyDeviceMessageWhenSyncCompletes_Activated() {
        // given
        setupSelfClient(inMoc: self.uiMOC)
        
        self.sut = AccountStatus(managedObjectContext: self.uiMOC)
        XCTAssertEqual(self.sut.accountState, AccountState.activated)
        
        let oneOnOne = ZMConversation.insertNewObject(in: self.uiMOC)
        oneOnOne.conversationType = .oneOnOne
        let group = ZMConversation.insertNewObject(in: self.uiMOC)
        group.conversationType = .group
        let connection = ZMConversation.insertNewObject(in: self.uiMOC)
        connection.conversationType = .connection
        let selfConv = ZMConversation.insertNewObject(in: self.uiMOC)
        selfConv.conversationType = .self
        
        XCTAssertEqual(self.sut.accountState, AccountState.activated)
        
        // when
        ZMUserSession.notifyInitialSyncCompleted(context: self.uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(oneOnOne.allMessages.count, 0)
        XCTAssertEqual(group.allMessages.count, 0)
        XCTAssertEqual(connection.allMessages.count, 0)
        
        XCTAssertEqual(self.sut.accountState, AccountState.activated)
    }
    
    
    func testThatItAppendsANewDeviceMessageWhenSyncCompletes_NewDevice() {
        // given
        setupSelfClient(inMoc: self.uiMOC)
        
        self.sut = AccountStatus(managedObjectContext: self.uiMOC)
        XCTAssertEqual(self.sut.accountState, AccountState.activated)

        PostLoginAuthenticationNotification.notifyClientRegistrationDidSucceed(context: uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let oneOnOne = ZMConversation.insertNewObject(in: self.uiMOC)
        oneOnOne.conversationType = .oneOnOne
        let group = ZMConversation.insertNewObject(in: self.uiMOC)
        group.conversationType = .group
        let connection = ZMConversation.insertNewObject(in: self.uiMOC)
        connection.conversationType = .connection
        let selfConv = ZMConversation.insertNewObject(in: self.uiMOC)
        selfConv.conversationType = .self
        
        XCTAssertEqual(self.sut.accountState, AccountState.newDevice)

        // when
        ZMUserSession.notifyInitialSyncCompleted(context: self.uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertEqual(oneOnOne.allMessages.count, 1)
        XCTAssertEqual(group.allMessages.count, 1)
        XCTAssertEqual(connection.allMessages.count, 0)
        if let oneOnOneMsg = oneOnOne.lastMessage as? ZMSystemMessage,
            let groupMsg = oneOnOne.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(oneOnOneMsg.systemMessageType, ZMSystemMessageType.usingNewDevice)
            XCTAssertEqual(groupMsg.systemMessageType, ZMSystemMessageType.usingNewDevice)
        } else {
            XCTFail()
        }
        
        XCTAssertEqual(self.sut.accountState, AccountState.activated)
    }
    
    func testThatItAppendsAReactivedDeviceMessageWhenSyncCompletes_ReactivatedDevice() {
        // given
        setupSelfClient(inMoc: self.uiMOC)
        
        let oneOnOne = ZMConversation.insertNewObject(in: self.uiMOC)
        oneOnOne.conversationType = .oneOnOne
        let group = ZMConversation.insertNewObject(in: self.uiMOC)
        group.conversationType = .group
        let connection = ZMConversation.insertNewObject(in: self.uiMOC)
        connection.conversationType = .connection
        let selfConv = ZMConversation.insertNewObject(in: self.uiMOC)
        selfConv.conversationType = .self
        
        self.sut = AccountStatus(managedObjectContext: self.uiMOC)
        sut.didCompleteLogin()
        XCTAssertEqual(self.sut.accountState, AccountState.deactivated)
        
        // when
        ZMUserSession.notifyInitialSyncCompleted(context: self.uiMOC)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(oneOnOne.allMessages.count, 1)
        XCTAssertEqual(group.allMessages.count, 1)
        XCTAssertEqual(connection.allMessages.count, 0)
        if let oneOnOneMsg = oneOnOne.lastMessage as? ZMSystemMessage, let groupMsg = oneOnOne.lastMessage as? ZMSystemMessage {
            XCTAssertEqual(oneOnOneMsg.systemMessageType, ZMSystemMessageType.reactivatedDevice)
            XCTAssertEqual(groupMsg.systemMessageType, ZMSystemMessageType.reactivatedDevice)
        } else {
            XCTFail()
        }
        
        XCTAssertEqual(self.sut.accountState, AccountState.activated)
    }
    
}
