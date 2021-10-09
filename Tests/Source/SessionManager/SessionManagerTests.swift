//

import XCTest
import WireTesting
import PushKit
@testable import WireSyncEngine

class SessionManagerTests: IntegrationTest {

    var delegate: SessionManagerTestDelegate!
    var sut: SessionManager?
    
    override func setUp() {
        super.setUp()
        delegate = SessionManagerTestDelegate()
        createSelfUserAndConversation()
    }
    
    func createManager() -> SessionManager? {
        guard let application = application else { return nil }
        let environment = MockEnvironment()
        let reachability = TestReachability()
        let unauthenticatedSessionFactory = MockUnauthenticatedSessionFactory(transportSession: mockTransportSession, environment: environment, reachability: reachability)
        let authenticatedSessionFactory = MockAuthenticatedSessionFactory(
            application: application,
            mediaManager: mockMediaManager,
            flowManager: FlowManagerMock(),
            transportSession: mockTransportSession,
            environment: environment,
            reachability: reachability
        )
        
        let sessionManager = SessionManager(
            appVersion: "0.0.0",
            authenticatedSessionFactory: authenticatedSessionFactory,
            unauthenticatedSessionFactory: unauthenticatedSessionFactory,
            reachability: reachability,
            delegate: delegate,
            application: application,
            pushRegistry: pushRegistry,
            dispatchGroup: dispatchGroup,
            environment: environment,
            configuration: sessionManagerConfiguration,
            detector: jailbreakDetector
        )
        
        sessionManager.start(launchOptions: [:])
        
        return sessionManager
    }
    
    override func tearDown() {
        delegate = nil
        sut = nil
        super.tearDown()
    }
    
    func testThatItCreatesUnauthenticatedSessionAndNotifiesDelegateIfStoreIsNotAvailable() {
        
        // given
        let observer = SessionManagerObserverMock()
        let token = sut?.addSessionManagerCreatedSessionObserver(observer)
        
        // when
        sut = createManager()
        
        // then
        XCTAssertNil(delegate.userSession)
        XCTAssertNotNil(sut?.unauthenticatedSession)
        withExtendedLifetime(token) {
            XCTAssertEqual([], observer.createdUserSession)
        }
    }
    
    func testThatItCreatesUserSessionAndNotifiesDelegateIfStoreIsAvailable() {
        // given
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let manager = AccountManager(sharedDirectory: sharedContainer)
        let account = Account(userName: "", userIdentifier: currentUserIdentifier)
        sessionManager!.environment.cookieStorage(for: account).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        manager.addAndSelect(account)

        var completed = false
        LocalStoreProvider.createStack(
            applicationContainer: sharedContainer,
            userIdentifier: currentUserIdentifier,
            dispatchGroup: dispatchGroup,
            completion: { _ in completed = true }
        )
        
        XCTAssert(wait(withTimeout: 0.5) { completed })

        // when
        sut = createManager()
        let observer = SessionManagerObserverMock()
        let token = sut?.addSessionManagerCreatedSessionObserver(observer)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        
        // then
        XCTAssertNotNil(delegate.userSession)
        XCTAssertNil(sut?.unauthenticatedSession)
        withExtendedLifetime(token) {
            XCTAssertEqual([delegate.userSession].compactMap { $0 }, observer.createdUserSession)
        }
    }
    
    func testThatItNotifiesObserverWhenCreatingAndTearingDownSession() {
        
        // GIVEN
        let account = self.createAccount()
        sessionManager!.environment.cookieStorage(for: account).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        
        guard let application = application else { return XCTFail() }
        
        let sessionManagerExpectation = self.expectation(description: "Session manager and session is loaded")

        var realSessionManager: SessionManager! = nil
        let observer = SessionManagerObserverMock()
        var createToken: Any? = nil
        var destroyToken: Any? = nil
        SessionManager.create(appVersion: "0.0.0",
                              mediaManager: MockMediaManager(),
                              analytics: nil,
                              delegate: nil,
                              application: application,
                              environment: sessionManager!.environment,
                              configuration: SessionManagerConfiguration(blacklistDownloadInterval: -1)) { sessionManager in
                                
                                let environment = MockEnvironment()
                                let reachability = TestReachability()
                                let authenticatedSessionFactory = MockAuthenticatedSessionFactory(
                                    application: application,
                                    mediaManager: MockMediaManager(),
                                    flowManager: FlowManagerMock(),
                                    transportSession: self.mockTransportSession,
                                    environment: environment,
                                    reachability: reachability
                                )
                                
                                sessionManager.authenticatedSessionFactory = authenticatedSessionFactory
                                sessionManager.start(launchOptions: [:])
                                
                                // WHEN
                                createToken = sessionManager.addSessionManagerCreatedSessionObserver(observer)
                                destroyToken = sessionManager.addSessionManagerDestroyedSessionObserver(observer)
                                
                                withExtendedLifetime(createToken) {
                                    sessionManager.loadSession(for: account) { userSession in
                                        realSessionManager = sessionManager
                                        XCTAssertNotNil(userSession)
                                        sessionManagerExpectation.fulfill()
                                    }
                                }
        }
        
        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertEqual([realSessionManager.activeUserSession!], observer.createdUserSession)
        
        // AND WHEN
        withExtendedLifetime(destroyToken) {
            realSessionManager.tearDownBackgroundSession(for: account.userIdentifier)
        }
    
        // THEN
        XCTAssertEqual([account.userIdentifier], observer.destroyedUserSessions)
    }
    
    func testThatItNotifiesDestroyedSessionObserverWhenCurrentSessionIsLoggedOut() {
        
        // GIVEN
        XCTAssertTrue(login())
        let account = sessionManager!.accountManager.selectedAccount!
        let observer = SessionManagerObserverMock()
        let token = sessionManager?.addSessionManagerDestroyedSessionObserver(observer)
        
        // WHEN
        withExtendedLifetime(token) {
            sessionManager?.logoutCurrentSession()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        
        // THEN
        XCTAssertEqual([account.userIdentifier], observer.destroyedUserSessions)
    }
    
    func testThatItNotifiesDestroyedSessionObserverWhenMemoryWarningReceived() {
        
        // GIVEN
        // Mock transport doesn't support multiple accounts at the moment so we pretend to be offline
        // in order to avoid the user session's getting stuck in a request loop.
        mockTransportSession.doNotRespondToRequests = true
        
        let account1 = self.createAccount()
        sessionManager!.environment.cookieStorage(for: account1).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        
        let account2 = self.createAccount(with: UUID.create())
        sessionManager!.environment.cookieStorage(for: account2).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        
        guard let application = application else { return XCTFail() }
        
        let sessionManagerExpectation = self.expectation(description: "Session manager and sessions are loaded")
        
        var realSessionManager: SessionManager! = nil
        let observer = SessionManagerObserverMock()
        
        var destroyToken: Any? = nil
        SessionManager.create(appVersion: "0.0.0",
                              mediaManager: MockMediaManager(),
                              analytics: nil,
                              delegate: nil,
                              application: application,
                              environment: sessionManager!.environment,
                              configuration: SessionManagerConfiguration(blacklistDownloadInterval: -1)) { sessionManager in
                                
                                let environment = MockEnvironment()
                                let reachability = TestReachability()
                                let authenticatedSessionFactory = MockAuthenticatedSessionFactory(
                                    application: application,
                                    mediaManager: MockMediaManager(),
                                    flowManager: FlowManagerMock(),
                                    transportSession: self.mockTransportSession,
                                    environment: environment,
                                    reachability: reachability
                                )
                                
                                sessionManager.authenticatedSessionFactory = authenticatedSessionFactory
                                sessionManager.start(launchOptions: [:])
                                
                                // WHEN
                                destroyToken = sessionManager.addSessionManagerDestroyedSessionObserver(observer)
                                
                                sessionManager.loadSession(for: account1) { userSession in
                                    realSessionManager = sessionManager
                                    XCTAssertNotNil(userSession)
                                    
                                    // load second account
                                    realSessionManager.loadSession(for: account2) { userSession in
                                        XCTAssertNotNil(userSession)
                                        sessionManagerExpectation.fulfill()
                                    }
                                }
        }
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertEqual(realSessionManager.backgroundUserSessions.count, 2)
        XCTAssertEqual(realSessionManager.backgroundUserSessions[account2.userIdentifier], realSessionManager.activeUserSession)
        
        withExtendedLifetime(destroyToken) {
            NotificationCenter.default.post(Notification(name: UIApplication.didReceiveMemoryWarningNotification))
        }
        
        // THEN
        XCTAssertEqual([account1.userIdentifier], observer.destroyedUserSessions)
    }
    
    func testThatJailbrokenDeviceCallsDelegateMethod() {
        
        //GIVEN
        guard let application = application else { return XCTFail() }
        let sessionManagerExpectation = self.expectation(description: "Session manager has detected a jailbroken device")
        let jailbreakDetector = MockJailbreakDetector(jailbroken: true)
        let configuration = SessionManagerConfiguration(blockOnJailbreakOrRoot: true)
        
        //WHEN
        SessionManager.create(appVersion: "0.0.0",
                              mediaManager: mockMediaManager,
                              analytics: nil,
                              delegate: self.delegate,
                              application: application,
                              environment: sessionManager!.environment,
                              configuration: configuration,
                              detector: jailbreakDetector) { sessionManager in
                                //THEN
                                XCTAssertTrue(self.delegate.jailbroken)
                                sessionManagerExpectation.fulfill()
        }
    
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatJailbrokenDeviceDeletesAccount() {
        //GIVEN
        sut = createManager()
        (sut?.jailbreakDetector as! MockJailbreakDetector).jailbroken = true
        sut?.configuration.wipeOnJailbreakOrRoot = true
        
        //WHEN
        sut?.accountManager.addAndSelect(createAccount())
        XCTAssertEqual(sut?.accountManager.accounts.count, 1)
        
        //THEN
        performIgnoringZMLogError {
            self.sut!.checkJailbreakIfNeeded()
        }
        XCTAssertEqual(self.sut?.accountManager.accounts.count, 0)
    }
    
    func testAuthenticationAfterReboot() {
        
        //GIVEN
        sut = createManager()
        sut?.configuration.authenticateAfterReboot = true

        //WHEN
        sut?.accountManager.addAndSelect(createAccount())
        XCTAssertEqual(sut?.accountManager.accounts.count, 1)
        SessionManager.previousSystemBootTime = Date(timeIntervalSince1970: 0)
        
        //THEN
        let logoutExpectation = expectation(description: "Authentication after reboot")
        
        delegate.onLogout = { error in
            XCTAssertNil(self.sut?.activeUserSession)
            XCTAssertEqual(error?.userSessionErrorCode, .needsAuthenticationAfterReboot)
            logoutExpectation.fulfill()
        }
        
        performIgnoringZMLogError {
            self.sut!.logoutAfterRebootIfNeeded()
        }
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 2))
    }
    
    
    func testAuthenticationAfterReboot_DoesntLogoutIfNotRebooted() {
        
        //GIVEN
        sut = createManager()
        sut?.configuration.authenticateAfterReboot = true
        sut?.accountManager.addAndSelect(createAccount())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(sut?.accountManager.accounts.count, 1)
        SessionManager.previousSystemBootTime = ProcessInfo.processInfo.systemBootTime
        
        // EXPECT
        delegate.onLogout = { _ in
            XCTFail("We should not have been logged out")
        }
        
        // WHEN
        performIgnoringZMLogError {
            self.sut!.logoutAfterRebootIfNeeded()
        }
    }
    
    func testAuthenticationAfterReboot_DoesntLogoutIfNoPreviousBootTimeExists() {
        
        //GIVEN
        sut = createManager()
        sut?.configuration.authenticateAfterReboot = true
        sut?.accountManager.addAndSelect(createAccount())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(sut?.accountManager.accounts.count, 1)
        ZMKeychain.deleteAllKeychainItems(withAccountName: SessionManager.previousSystemBootTimeContainer)
        
        // EXPECT
        delegate.onLogout = { _ in
            XCTFail("We should not have been logged out")
        }
        
        // WHEN
        performIgnoringZMLogError {
            self.sut!.logoutAfterRebootIfNeeded()
        }
    }
    
}

extension IntegrationTest {
    func createAccount() -> Account {
        return createAccount(with: currentUserIdentifier)
    }
    
    func createAccount(with id: UUID) -> Account {
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else {
            XCTFail()
            fatalError()
        }
        
        let manager = AccountManager(sharedDirectory: sharedContainer)
        let account = Account(userName: "Test Account", userIdentifier: id)
        manager.addOrUpdate(account)
        
        return account
    }

    func createSelfClient(_ context: NSManagedObjectContext) -> UserClient {
        let selfClient = UserClient.insertNewObject(in: context)
        selfClient.remoteIdentifier = nil
        selfClient.user = ZMUser.selfUser(in: context)
        return selfClient
    }
}

class SessionManagertests_AccountDeletion: IntegrationTest {
    
    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
    }
    
    func testThatItDeletesTheAccountFolder_WhenDeletingAccountWithoutActiveUserSession() throws {
        // given
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else {
            XCTFail()
            return
        }
        let account = self.createAccount()
        
        let accountFolder = StorageStack.accountFolder(accountIdentifier: account.userIdentifier, applicationContainer: sharedContainer)
        
        try FileManager.default.createDirectory(at: accountFolder, withIntermediateDirectories: true, attributes: nil)
        
        // when
        performIgnoringZMLogError {
            self.sessionManager!.delete(account: account)
        }
        
        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: accountFolder.path))
    }
    
    func testThatItDeletesTheAccountFolder_WhenDeletingActiveUserSessionAccount() throws {
        // given
        XCTAssert(login())
        
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        
        let account = sessionManager!.accountManager.selectedAccount!
        let accountFolder = StorageStack.accountFolder(accountIdentifier: account.userIdentifier, applicationContainer: sharedContainer)
        
        // when
        performIgnoringZMLogError {
            self.sessionManager!.delete(account: account)
        }
        
        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: accountFolder.path))
    }
    
}

class SessionManagerTests_AuthenticationFailure: IntegrationTest {
    
    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
    }
    
    func testThatItDeletesTheCookie_OnAuthentictionFailure() {
        // given
        XCTAssert(login())
        XCTAssertTrue(sessionManager!.isSelectedAccountAuthenticated)
        
        // when
        let account = sessionManager!.accountManager.selectedAccount!
        sessionManager?.authenticationInvalidated(NSError(code: .accessTokenExpired, userInfo: nil), accountId: account.userIdentifier)
        
        // then
        XCTAssertFalse(sessionManager!.isSelectedAccountAuthenticated)
    }
    
    func testThatItTearsDownActiveUserSession_OnAuthentictionFailure() {
        // given
        XCTAssert(login())
        XCTAssertNotNil(sessionManager?.activeUserSession)
        
        // when
        let account = sessionManager!.accountManager.selectedAccount!
        sessionManager?.authenticationInvalidated(NSError(code: .accessTokenExpired, userInfo: nil), accountId: account.userIdentifier)
        
        // then
        XCTAssertNil(sessionManager?.activeUserSession)
    }
    
    func testThatItTearsDownBackgroundUserSession_OnAuthentictionFailure() {
        // given
        let additionalAccount = Account(userName: "Additional Account", userIdentifier: UUID())
        sessionManager!.environment.cookieStorage(for: additionalAccount).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        sessionManager!.accountManager.addOrUpdate(additionalAccount)
        
        XCTAssert(login())
        XCTAssertNotNil(sessionManager?.activeUserSession)
        
        // load additional account as a background session
        sessionManager!.withSession(for: additionalAccount, perform: { _ in })
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertNotNil(sessionManager?.backgroundUserSessions[additionalAccount.userIdentifier])
        
        // when
        sessionManager?.authenticationInvalidated(NSError(code: .accessTokenExpired, userInfo: nil), accountId: additionalAccount.userIdentifier)
        
        // then
        XCTAssertNil(sessionManager?.backgroundUserSessions[additionalAccount.userIdentifier])
    }
    
}

class SessionManagerTests_AuthenticationFailure_With_DeleteAccountOnAuthentictionFailure: IntegrationTest {
    
    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
    }
    
    override var sessionManagerConfiguration: SessionManagerConfiguration {
        return SessionManagerConfiguration(wipeOnCookieInvalid: true)
    }
    
    func testThatItDeletesTheAccount_OnLaunchIfAccessTokenHasExpired() {
        // given
        XCTAssertTrue(login())
        let account = sessionManager!.accountManager.selectedAccount!
        
        // when
        deleteAuthenticationCookie()
        recreateSessionManager()
        
        // then
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let accountFolder = StorageStack.accountFolder(accountIdentifier: account.userIdentifier, applicationContainer: sharedContainer)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: accountFolder.path))
    }
    
    func testThatItDeletesTheAccount_OnAuthentictionFailure() {
        // given
        XCTAssert(login())
        let account = sessionManager!.accountManager.selectedAccount!
        
        // when
        sessionManager?.authenticationInvalidated(NSError(code: .accessTokenExpired, userInfo: nil), accountId: account.userIdentifier)
        
        // then
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let accountFolder = StorageStack.accountFolder(accountIdentifier: account.userIdentifier, applicationContainer: sharedContainer)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: accountFolder.path))
    }
    
    func testThatItDeletesTheAccount_OnAuthentictionFailureForBackgroundSession() {
        // given
        let additionalAccount = Account(userName: "Additional Account", userIdentifier: UUID())
        sessionManager!.environment.cookieStorage(for: additionalAccount).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        sessionManager!.accountManager.addOrUpdate(additionalAccount)
        
        XCTAssert(login())
        
        XCTAssertNotNil(sessionManager?.activeUserSession)
        
        // load additional account as a background session
        let sessionLoaded = expectation(description: "Background session loaded")
        sessionManager?.withSession(for: additionalAccount, perform: {_ in
            sessionLoaded.fulfill()
        })
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertNotNil(sessionManager?.backgroundUserSessions[additionalAccount.userIdentifier])
        
        // when
        sessionManager?.authenticationInvalidated(NSError(code: .accessTokenExpired, userInfo: nil), accountId: additionalAccount.userIdentifier)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))  
        
        // then
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let accountFolder = StorageStack.accountFolder(accountIdentifier: additionalAccount.userIdentifier, applicationContainer: sharedContainer)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: accountFolder.path))
    }
    
}

class SessionManagerTests_Teams: IntegrationTest {
    
    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
    }
    
    
    func testThatItUpdatesAccountAfterLoginWithTeamName() {
        // given
        let teamName = "Wire"
        let image = MockAsset(in: mockTransportSession.managedObjectContext, forID: selfUser.previewProfileAssetIdentifier!)
        self.mockTransportSession.performRemoteChanges { session in
            _ = session.insertTeam(withName: teamName, isBound: true, users: [self.selfUser])
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        XCTAssert(login())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        let _ = MockAsset(in: mockTransportSession.managedObjectContext, forID: selfUser.previewProfileAssetIdentifier!)
        
        // then
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let manager = AccountManager(sharedDirectory: sharedContainer)
        guard let account = manager.accounts.first, manager.accounts.count == 1 else { XCTFail("Should have one account"); return }
        XCTAssertEqual(account.userIdentifier.transportString(), self.selfUser.identifier)
        XCTAssertEqual(account.teamName, teamName)
        XCTAssertEqual(account.imageData, image?.data)
        XCTAssertNil(account.teamImageData)
        XCTAssertEqual(account.loginCredentials, selfUser.loginCredentials)
    }
    
    func testThatItUpdatesAccountAfterTeamNameChanges() {
        // given
        var team: MockTeam!
        self.mockTransportSession.performRemoteChanges { session in
            team = session.insertTeam(withName: "Wire", isBound: true, users: [self.selfUser])
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        XCTAssert(login())
        
        let newTeamName = "Not Wire"
        self.mockTransportSession.performRemoteChanges { session in
            team.name = newTeamName
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let account = sessionManager?.accountManager.accounts.first, sessionManager?.accountManager.accounts.count == 1 else { XCTFail("Should have one account"); return }
        XCTAssertEqual(account.userIdentifier.transportString(), self.selfUser.identifier)
        XCTAssertEqual(account.teamName, newTeamName)
    }
    
    func testThatItUpdatesAccountAfterTeamImageDataChanges() {
        // given
        let assetData = "image".data(using: .utf8)!
        var asset: MockAsset!
        var team: MockTeam!
        self.mockTransportSession.performRemoteChanges { session in
            team = session.insertTeam(withName: "Wire", isBound: true, users: [self.selfUser])
            asset = session.insertAsset(with: UUID(), assetToken: UUID(), assetData: assetData, contentType: "image/jpeg")
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssert(login())
        
        // when
        self.mockTransportSession.performRemoteChanges { session in
            team.pictureAssetId = asset.identifier
        }
        user(for: selfUser)?.team?.requestImage()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let account = sessionManager?.accountManager.accounts.first, sessionManager?.accountManager.accounts.count == 1 else { XCTFail("Should have one account"); return }
        XCTAssertEqual(account.userIdentifier.transportString(), self.selfUser.identifier)
        XCTAssertEqual(account.teamImageData, assetData)
    }
    
    func testThatItUpdatesAccountWithUserDetailsAfterLogin() {
        // when
        XCTAssert(login())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let manager = AccountManager(sharedDirectory: sharedContainer)
        guard let account = manager.accounts.first, manager.accounts.count == 1 else { XCTFail("Should have one account"); return }
        XCTAssertEqual(account.userIdentifier.transportString(), self.selfUser.identifier)
        XCTAssertNil(account.teamName)
        XCTAssertEqual(account.userName, self.selfUser.name)
        let image = MockAsset(in: mockTransportSession.managedObjectContext, forID: selfUser.previewProfileAssetIdentifier!)

        XCTAssertEqual(account.imageData, image?.data)
    }
    
    func testThatItUpdatesAccountWithUserDetailsAfterLoginIntoExistingAccount() {        
        // given
        XCTAssert(login())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        sessionManager?.logoutCurrentSession()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssert(login())
        
        // then
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let manager = AccountManager(sharedDirectory: sharedContainer)
        guard let account = manager.accounts.first, manager.accounts.count == 1 else { XCTFail("Should have one account"); return }
        XCTAssertEqual(account.userIdentifier.transportString(), self.selfUser.identifier)
        XCTAssertNil(account.teamName)
        XCTAssertEqual(account.userName, self.selfUser.name)
        let image = MockAsset(in: mockTransportSession.managedObjectContext, forID: selfUser.previewProfileAssetIdentifier!)
        
        XCTAssertEqual(account.imageData, image?.data)
    }
    
    func testThatItUpdatesAccountAfterUserNameChange() {
        // when
        XCTAssert(login())
        
        let newName = "BOB"
        self.mockTransportSession.performRemoteChanges { session in
            self.selfUser.name = newName
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        let manager = AccountManager(sharedDirectory: sharedContainer)
        guard let account = manager.accounts.first, manager.accounts.count == 1 else { XCTFail("Should have one account"); return }
        XCTAssertEqual(account.userIdentifier.transportString(), self.selfUser.identifier)
        XCTAssertNil(account.teamName)
        XCTAssertEqual(account.userName, selfUser.name)
    }
    
    func testThatItSendsAuthenticationErrorWhenAccountLimitIsReached() throws {
        // given
        let account1 = Account(userName: "Account 1", userIdentifier: UUID.create())
        let account2 = Account(userName: "Account 2", userIdentifier: UUID.create())
        let account3 = Account(userName: "Account 3", userIdentifier: UUID.create())
        
        sessionManager?.accountManager.addOrUpdate(account1)
        sessionManager?.accountManager.addOrUpdate(account2)
        sessionManager?.accountManager.addOrUpdate(account3)
        
        let recorder = PreLoginAuthenticationNotificationRecorder(authenticationStatus: sessionManager!.unauthenticatedSession!.authenticationStatus)
        
        // when
        XCTAssert(login(ignoreAuthenticationFailures: true))

        // then
        XCTAssertEqual(NSError(code: .accountLimitReached, userInfo: nil), recorder.notifications.last!.error)
    }

    func testThatItChecksAccountsForExistingAccount() {
        // given
        let account1 = Account(userName: "Account 1", userIdentifier: UUID.create())
        let account2 = Account(userName: "Account 2", userIdentifier: UUID.create())

        sessionManager?.accountManager.addOrUpdate(account1)

        // then
        XCTAssertTrue(sessionManager!.session(session: self.unauthenticatedSession!, isExistingAccount: account1))
        XCTAssertFalse(sessionManager!.session(session: self.unauthenticatedSession!, isExistingAccount: account2))
    }
}

class SessionManagerTests_MultiUserSession: IntegrationTest {
    
    override func setUp() {
         super.setUp()
        
        // Mock transport doesn't support multiple accounts at the moment so we pretend to be offline
        // in order to avoid the user session's getting stuck in a request loop.
        mockTransportSession.doNotRespondToRequests = true
    }
    
    func testThatItLoadsAndKeepsBackgroundUserSession() {
        // GIVEN
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        
        let manager = AccountManager(sharedDirectory: sharedContainer)
        let account1 = Account(userName: "Test Account 1", userIdentifier: currentUserIdentifier)
        manager.addOrUpdate(account1)
        
        let account2 = Account(userName: "Test Account 2", userIdentifier: UUID())
        manager.addOrUpdate(account2)
        // WHEN
        weak var sessionForAccount1Reference: ZMUserSession? = nil
        let session1LoadedExpectation = self.expectation(description: "Session for account 1 loaded")
        self.sessionManager!.withSession(for: account1, perform: { sessionForAccount1 in
            // THEN
            session1LoadedExpectation.fulfill()
            XCTAssertNotNil(sessionForAccount1.managedObjectContext)
            sessionForAccount1Reference = sessionForAccount1
        })
        // WHEN
        weak var sessionForAccount2Reference: ZMUserSession? = nil
        let session2LoadedExpectation = self.expectation(description: "Session for account 2 loaded")
        self.sessionManager!.withSession(for: account1, perform: { sessionForAccount2 in
            // THEN
            session2LoadedExpectation.fulfill()
            XCTAssertNotNil(sessionForAccount2.managedObjectContext)
            sessionForAccount2Reference = sessionForAccount2
        })
        
        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5) { error in
            XCTAssertNil(error)
            XCTAssertNotNil(sessionForAccount1Reference)
            XCTAssertNotNil(sessionForAccount2Reference)
            
            self.sessionManager!.tearDownAllBackgroundSessions()
        })
    }
    
    func testThatItUnloadsUserSession() {
        // GIVEN
        let account = self.createAccount()
        
        // WHEN
        let sessionLoadedExpectation = self.expectation(description: "Session loaded")
        self.sessionManager!.withSession(for: account, perform: { session in
            XCTAssertNotNil(session.managedObjectContext)
            sessionLoadedExpectation.fulfill()
        })
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        
        // THEN
        XCTAssertNotNil(self.sessionManager!.backgroundUserSessions[account.userIdentifier])
        
        // AND WHEN
        self.sessionManager!.tearDownAllBackgroundSessions()
        
        // THEN
        XCTAssertNil(self.sessionManager!.backgroundUserSessions[account.userIdentifier])
    }
    
    func testThatItDoesNotUnloadActiveUserSessionFromMemoryWarning() {
        // GIVEN
        let account = self.createAccount()
        sessionManager!.environment.cookieStorage(for: account).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        
        guard let application = application else { return XCTFail() }
        
        let sessionManagerExpectation = self.expectation(description: "Session manager and session is loaded")
        
        // WHEN
        var realSessionManager: SessionManager! = nil
        SessionManager.create(appVersion: "0.0.0",
                              mediaManager: MockMediaManager(),
                              analytics: nil,
                              delegate: nil,
                              application: application,
                              environment: sessionManager!.environment,
                              configuration: SessionManagerConfiguration(blacklistDownloadInterval: -1)) { sessionManager in
                                
                                let environment = MockEnvironment()
                                let reachability = TestReachability()
                                let authenticatedSessionFactory = MockAuthenticatedSessionFactory(
                                    application: application,
                                    mediaManager: MockMediaManager(),
                                    flowManager: FlowManagerMock(),
                                    transportSession: self.mockTransportSession,
                                    environment: environment,
                                    reachability: reachability
                                )
                                
                                sessionManager.authenticatedSessionFactory = authenticatedSessionFactory
                                sessionManager.start(launchOptions: [:])
                                
                                sessionManager.loadSession(for: account) { userSession in
                                    realSessionManager = sessionManager
                                    XCTAssertNotNil(userSession)
                                    sessionManagerExpectation.fulfill()
                                }
        }
        
        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        
        XCTAssertNotNil(realSessionManager.backgroundUserSessions[account.userIdentifier])
        
        // WHEN
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // THEN
        XCTAssertNotNil(realSessionManager.backgroundUserSessions[account.userIdentifier])
        
        // CLEANUP
        realSessionManager.tearDownAllBackgroundSessions()
    }
    
    func testThatItUnloadBackgroundUserSessionFromMemoryWarning() {
        // GIVEN
        let account = self.createAccount()
        sessionManager!.environment.cookieStorage(for: account).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        
        guard let application = application else { return XCTFail() }
        
        let sessionManagerExpectation = self.expectation(description: "Session manager and session is loaded")

        // WHEN
        var realSessionManager: SessionManager! = nil
        SessionManager.create(appVersion: "0.0.0",
                       mediaManager: MockMediaManager(),
                       analytics: nil,
                       delegate: nil,
                       application: application,
                       environment: sessionManager!.environment,
                       configuration: SessionManagerConfiguration(blacklistDownloadInterval: -1)) { sessionManager in
                        
                        let environment = MockEnvironment()
                        let reachability = TestReachability()
                        let authenticatedSessionFactory = MockAuthenticatedSessionFactory(
                            application: application,
                            mediaManager: MockMediaManager(),
                            flowManager: FlowManagerMock(),
                            transportSession: self.mockTransportSession,
                            environment: environment,
                            reachability: reachability
                        )
                        
                        sessionManager.authenticatedSessionFactory = authenticatedSessionFactory
                        sessionManager.start(launchOptions: [:])

            sessionManager.withSession(for: account) { userSession in
                realSessionManager = sessionManager
                XCTAssertNotNil(userSession)
                sessionManagerExpectation.fulfill()
            }
        }
        
        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        
        XCTAssertNotNil(realSessionManager.backgroundUserSessions[account.userIdentifier])
        
        // WHEN
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // THEN
        XCTAssertNil(realSessionManager.backgroundUserSessions[account.userIdentifier])
        
        // CLEANUP
        realSessionManager.tearDownAllBackgroundSessions()
    }
    
    func prepareSession(for account: Account) {
        weak var weakSession: ZMUserSession? = nil
        
        autoreleasepool {
            var session: ZMUserSession! = nil
            self.sessionManager?.withSession(for: account, perform: { createdSession in
                session = createdSession
                weakSession = createdSession
            })
            
            XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
            
            let selfUser = ZMUser.selfUser(inUserSession: session)
            selfUser.remoteIdentifier = currentUserIdentifier
        
            self.sessionManager!.tearDownAllBackgroundSessions()
            XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
            session = nil
            XCTAssertNil(self.sessionManager!.backgroundUserSessions[account.userIdentifier])
        }
        self.userSession = nil
        XCTAssertNil(weakSession)
    }
    
    func testThatItLoadsAccountForPush() {
        // GIVEN
        let account = Account(userName: "Test Account", userIdentifier: currentUserIdentifier)
        self.sessionManager?.accountManager.addOrUpdate(account)

        self.prepareSession(for: account)
        
        let payload: [AnyHashable: Any] = ["data": [
            "user": currentUserIdentifier.transportString()
            ]
        ]
        
        // WHEN
        let pushCompleted = self.expectation(description: "Push completed")
        pushRegistry.mockIncomingPushPayload(payload, completion: {
            DispatchQueue.main.async {
                // THEN
                XCTAssertNotNil(self.sessionManager!.backgroundUserSessions[account.userIdentifier])
                
                // CLEANUP
                self.sessionManager!.tearDownAllBackgroundSessions()
                pushCompleted.fulfill()
            }
        })
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatItLoadsOnlyOneAccountForPush() {
        // GIVEN
        let account = Account(userName: "Test Account", userIdentifier: currentUserIdentifier)
        self.sessionManager?.accountManager.addOrUpdate(account)
        
        self.prepareSession(for: account)
        
        let payload: [AnyHashable: Any] = ["data": [
            "user": currentUserIdentifier.transportString()
            ]
        ]
        
        // WHEN
        let pushCompleted1 = self.expectation(description: "Push completed 1")
        var userSession1: ZMUserSession!
        let pushCompleted2 = self.expectation(description: "Push completed 2")
        var userSession2: ZMUserSession!
        pushRegistry.mockIncomingPushPayload(payload, completion: {
            pushCompleted1.fulfill()
            userSession1 = self.sessionManager!.backgroundUserSessions[account.userIdentifier]
        })
        pushRegistry.mockIncomingPushPayload(payload, completion: {
            pushCompleted2.fulfill()
            userSession2 = self.sessionManager!.backgroundUserSessions[account.userIdentifier]
        })
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertNotNil(userSession1)
        XCTAssertNotNil(userSession2)
        XCTAssertEqual(userSession1, userSession2)
        // CLEANUP
        self.sessionManager!.tearDownAllBackgroundSessions()
    }
    
    func setupSession() -> ZMUserSession {
        let manager = self.sessionManager!.accountManager
        let account = Account(userName: "Test Account", userIdentifier: currentUserIdentifier)
        manager.addOrUpdate(account)
        sessionManager!.environment.cookieStorage(for: account).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        manager.addAndSelect(account)
        
        var session: ZMUserSession! = nil
        
        let sessionLoadExpectation = self.expectation(description: "Session loaded")
        self.sessionManager?.withSession(for: account, perform: { createdSession in
            session = createdSession
            sessionLoadExpectation.fulfill()
        })
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        
        let selfUser = ZMUser.selfUser(in: session.managedObjectContext)
        selfUser.remoteIdentifier = currentUserIdentifier
        session.managedObjectContext.saveOrRollback()

        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        _ = createSelfClient(session.managedObjectContext)
        
        session.syncManagedObjectContext.performGroupedBlock {
            let _ = ZMConversation(remoteID: self.currentUserIdentifier, createIfNeeded: true, in: session.syncManagedObjectContext)
            session.syncManagedObjectContext.saveOrRollback()
        }
        
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        return session
    }
    
    func testThatItConfiguresNotificationSettingsWhenAccountIsActivated() {
        // GIVEN
        _ = self.setupSession()
        let expectation = self.expectation(description: "Session loaded")
        sessionManager?.notificationCenter = notificationCenter!
        
        guard
            let sessionManager = self.sessionManager,
            let account = sessionManager.accountManager.account(with: currentUserIdentifier)
            else { return XCTFail() }
        
        // WHEN
        sessionManager.select(account, completion: { userSession in
            XCTAssertNotNil(userSession)
            expectation.fulfill()
        })
        
        XCTAssertTrue(self.wait(withTimeout: 0.1) { return self.sessionManager!.activeUserSession != nil })
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        XCTAssertEqual(self.notificationCenter?.registeredNotificationCategories, WireSyncEngine.PushNotificationCategory.allCategories)
        XCTAssertEqual(self.notificationCenter?.requestedAuthorizationOptions, [.alert, .badge, .sound])
        XCTAssertNotNil(self.notificationCenter?.delegate)
        
        // CLEANUP
        self.sessionManager!.tearDownAllBackgroundSessions()
    }
    
    func testThatItActivatesTheAccountForPushReaction() {
        // GIVEN
        let session = self.setupSession()
        session.isPerformingSync = false
        session.pushChannelIsOpen = true
        application?.applicationState = .background
        
        let selfConversation = ZMConversation(remoteID: currentUserIdentifier, createIfNeeded: false, in: session.managedObjectContext)

        let userInfo = NotificationUserInfo()
        userInfo.conversationID = selfConversation?.remoteIdentifier
        userInfo.selfUserID = currentUserIdentifier
        
        let category = WireSyncEngine.PushNotificationCategory.conversation.rawValue

        XCTAssertNil(self.sessionManager!.activeUserSession)

        // WHEN
        self.sessionManager?.handleNotification(with: userInfo) { userSession in
            userSession.handleNotificationResponse(actionIdentifier: "",
                                                   categoryIdentifier: category,
                                                   userInfo: userInfo,
                                                   completionHandler: {})
        }

        XCTAssertTrue(self.wait(withTimeout: 0.1) { return self.sessionManager!.activeUserSession != nil })
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.sessionManager!.activeUserSession, session)

        // CLEANUP
        self.sessionManager!.tearDownAllBackgroundSessions()
    }

    func testThatItActivatesTheAccountForPushAction() {
        // GIVEN
        let session = self.setupSession()
        session.isPerformingSync = false
        session.pushChannelIsOpen = true
        application?.applicationState = .inactive

        let selfConversation = ZMConversation(remoteID: currentUserIdentifier, createIfNeeded: false, in: session.managedObjectContext)
        
        let userInfo = NotificationUserInfo()
        userInfo.conversationID = selfConversation?.remoteIdentifier
        userInfo.selfUserID = currentUserIdentifier
        
        let category = WireSyncEngine.PushNotificationCategory.conversation.rawValue
        
        XCTAssertNil(self.sessionManager!.activeUserSession)

        // WHEN
        let completionExpectation = self.expectation(description: "Completed action")
        self.sessionManager?.handleNotification(with: userInfo) { userSession in
            userSession.handleNotificationResponse(actionIdentifier: "",
                                                   categoryIdentifier: category,
                                                   userInfo: userInfo,
                                                   completionHandler: completionExpectation.fulfill)
        }
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(self.sessionManager!.activeUserSession, session)

        // CLEANUP
        self.sessionManager!.tearDownAllBackgroundSessions()
    }
    
    func testThatItCallsForegroundNotificationResponderMethod() {
        // GIVEN
        let session = self.setupSession()
        session.isPerformingSync = false
        session.pushChannelIsOpen = true
        
        let responder = MockForegroundNotificationResponder()
        self.sessionManager?.foregroundNotificationResponder = responder
        
        let selfConversation = ZMConversation(remoteID: currentUserIdentifier, createIfNeeded: false, in: session.managedObjectContext)
        
        let userInfo = NotificationUserInfo()
        userInfo.conversationID = selfConversation?.remoteIdentifier
        userInfo.selfUserID = currentUserIdentifier
        
        let category = WireSyncEngine.PushNotificationCategory.conversation.rawValue
        
        XCTAssertTrue(responder.notificationPermissionRequests.isEmpty)
        
        // WHEN
        let completionExpectation = self.expectation(description: "Completed action")
        self.sessionManager?.handleNotification(with: userInfo) { userSession in
            userSession.handleInAppNotification(with: userInfo, categoryIdentifier: category) { _ in
                completionExpectation.fulfill()
            }
        }
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        XCTAssertEqual(responder.notificationPermissionRequests.count, 1)
        XCTAssertEqual(responder.notificationPermissionRequests.first!, selfConversation?.remoteIdentifier)
        
        // CLEANUP
        self.sessionManager!.tearDownAllBackgroundSessions()
    }
    
    func testThatItActivatesAccountWhichReceivesACallInTheBackground() {
        // GIVEN
        let manager = sessionManager!.accountManager
        let account1 = Account(userName: "Test Account 1", userIdentifier: currentUserIdentifier)
        sessionManager!.environment.cookieStorage(for: account1).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        
        manager.addOrUpdate(account1)
        let account2 = Account(userName: "Test Account 2", userIdentifier: UUID())
        sessionManager!.environment.cookieStorage(for: account2).authenticationCookieData = NSData.secureRandomData(ofLength: 16)
        manager.addOrUpdate(account2)
        
        // Make account 1 the active session
        weak var session1: ZMUserSession? = nil
        sessionManager?.loadSession(for: account1, completion: { (session) in
            session1 = session
        })
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(sessionManager!.activeUserSession, session1)
        
        // Load session for account 2 in the background
        weak var session2: ZMUserSession? = nil
        weak var conversation: ZMConversation? = nil
        weak var caller: ZMUser? = nil
        self.sessionManager!.withSession(for: account2, perform: { session in
            session2 = session
            conversation = ZMConversation.insertNewObject(in: session.managedObjectContext)
            caller = ZMUser.insertNewObject(in: session.managedObjectContext)
        })
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // WHEN
        sessionManager?.callCenterDidChange(callState: .answered(degraded: false), conversation: conversation!, caller: caller!, timestamp: nil, previousCallState: nil)
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        XCTAssertEqual(sessionManager!.activeUserSession, session2)
        
        // CLEANUP
        self.sessionManager!.tearDownAllBackgroundSessions()
    }
    
    // the purpose of this test is to ensure push payloads can be processed in
    // the background as soon as the SessionManager is created
    func testThatABackgroundTaskCanBeCreatedAfterCreatingSessionManager() {
        // WHEN
        let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: "PushActivity")
        
        // THEN
        XCTAssertNotNil(activity)
    }
}

extension NSManagedObjectContext {
    func createSelfUserAndSelfConversation() {
        let selfUser = ZMUser.selfUser(in: self)
        selfUser.remoteIdentifier = UUID()
        
        let selfConversation = ZMConversation.insertNewObject(in: self)
        selfConversation.remoteIdentifier = ZMConversation.selfConversationIdentifier(in: self)
    }
}

extension SessionManagerTests {
    func testThatItMarksConversationsAsRead() {
        // given
        let account1 = Account(userName: "Account 1", userIdentifier: UUID.create())
        let account2 = Account(userName: "Account 2", userIdentifier: UUID.create())
        
        sessionManager?.accountManager.addOrUpdate(account1)
        sessionManager?.accountManager.addOrUpdate(account2)
        
        var conversations: [ZMConversation] = []

        let conversation1CreatedExpectation = self.expectation(description: "Conversation 1 created")

        self.sessionManager?.withSession(for: account1, perform: { createdSession in
            createdSession.managedObjectContext.createSelfUserAndSelfConversation()
            
            let conversation1 = createdSession.insertConversationWithUnreadMessage()
            conversations.append(conversation1)
            XCTAssertNotNil(conversation1.firstUnreadMessage)
            createdSession.managedObjectContext.saveOrRollback()
            conversation1CreatedExpectation.fulfill()
        })
        
        let conversation2CreatedExpectation = self.expectation(description: "Conversation 2 created")
        
        self.sessionManager?.withSession(for: account2, perform: { createdSession in
            createdSession.managedObjectContext.createSelfUserAndSelfConversation()
            
            let conversation2 = createdSession.insertConversationWithUnreadMessage()
            XCTAssertNotNil(conversation2.firstUnreadMessage)
            conversations.append(conversation2)
            createdSession.managedObjectContext.saveOrRollback()
            conversation2CreatedExpectation.fulfill()
        })
        
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertEqual(conversations.count, 2)
        XCTAssertEqual(conversations.filter { $0.firstUnreadMessage != nil }.count, 2)
        
        // when
        let doneExpectation = self.expectation(description: "Conversations are marked as read")

        self.sessionManager?.markAllConversationsAsRead(completion: {
            doneExpectation.fulfill()
        })
        
        // then
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        
        XCTAssertEqual(conversations.filter { $0.firstUnreadMessage != nil }.count, 0)
        
        // cleanup
        self.sessionManager!.tearDownAllBackgroundSessions()
    }
}

final class MockSessionManagerURLHandlerDelegate: NSObject, SessionManagerURLHandlerDelegate  {

    var allowedAction: URLAction?

    func sessionManagerShouldExecuteURLAction(_ action: URLAction, callback: @escaping (Bool) -> Void) {
        callback(action == allowedAction)
    }

}

extension SessionManagerTests {

    func testThatItLogsOutWithCompanyLoginURL() {
        // GIVEN
        let id = UUID(uuidString: "1E628B42-4C83-49B7-B2B4-EF27BFE503EF")!
        let url = URL(string: "wire://start-sso/wire-\(id)")!

        sut = createManager()

        let urlDelegate = MockSessionManagerURLHandlerDelegate()
        urlDelegate.allowedAction = URLAction.startCompanyLogin(code: id)
        sut?.urlHandler.delegate = urlDelegate

        // WHEN
        let logoutExpectation = expectation(description: "The company login flow starts when the user adds .")

        delegate.onLogout = { error in
            let loginCode = error?.userInfo[SessionManager.companyLoginCodeKey]
            XCTAssertEqual(loginCode as? UUID, id)
            XCTAssertEqual(error?.userSessionErrorCode, .addAccountRequested)
            logoutExpectation.fulfill()
        }

        sut?.urlHandler.openURL(url, options: [:])

        // THEN
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 2))

        // CLEANUP
        self.sut!.tearDownAllBackgroundSessions()
    }

}

// MARK: - Mocks
class SessionManagerTestDelegate: SessionManagerDelegate {

    var onLogout: ((NSError?) -> Void)?
    func sessionManagerWillLogout(error: Error?, userSessionCanBeTornDown: (() -> Void)?) {
        onLogout?(error as NSError?)
        userSessionCanBeTornDown?()
    }
    
    func sessionManagerDidFailToLogin(account: Account?, error: Error) {
        // no op
    }
    
    func sessionManagerWillOpenAccount(_ account: Account, userSessionCanBeTornDown: @escaping () -> Void) {
        userSessionCanBeTornDown()
    }
    
    func sessionManagerDidBlacklistCurrentVersion() {
        // no op
    }
    
    var jailbroken = false
    
    func sessionManagerDidBlacklistJailbrokenDevice() {
        jailbroken = true
    }
    
    var userSession : ZMUserSession?
    func sessionManagerActivated(userSession: ZMUserSession) {
        self.userSession = userSession
    }
    
    var startedMigrationCalled = false
    func sessionManagerWillMigrateAccount(_ account: Account) {
        startedMigrationCalled = true
    }
    
    func sessionManagerWillMigrateLegacyAccount() {
        // no op
    }

}

class SessionManagerObserverMock: SessionManagerCreatedSessionObserver, SessionManagerDestroyedSessionObserver {
    
    var createdUserSession: [ZMUserSession] = []
    var createdUnauthenticatedSession: [UnauthenticatedSession] = []
    var destroyedUserSessions: [UUID] = []
    
    func sessionManagerCreated(userSession: ZMUserSession) {
        createdUserSession.append(userSession)
    }

    func sessionManagerCreated(unauthenticatedSession: UnauthenticatedSession) {
        createdUnauthenticatedSession.append(unauthenticatedSession)
    }
    
    func sessionManagerDestroyedUserSession(for accountId: UUID) {
        destroyedUserSessions.append(accountId)
    }
    
}

class TestReachability: NSObject, ReachabilityProvider, TearDownCapable {
    var mayBeReachable = true
    var isMobileConnection = true
    var oldMayBeReachable = true
    var oldIsMobileConnection = true
    
    var tearDownCalled = false
    func tearDown() {
        tearDownCalled = true
    }
    
    func add(_ observer: ZMReachabilityObserver, queue: OperationQueue?) -> Any {
        return NSObject()
    }
    
    func addReachabilityObserver(on queue: OperationQueue?, block: @escaping ReachabilityObserverBlock) -> Any {
        return NSObject()
    }
}

class MockForegroundNotificationResponder: NSObject, ForegroundNotificationResponder {
    
    var notificationPermissionRequests: [UUID] = []
    
    func shouldPresentNotification(with userInfo: NotificationUserInfo) -> Bool {
        notificationPermissionRequests.append(userInfo.conversationID!)
        return true
    }
}
