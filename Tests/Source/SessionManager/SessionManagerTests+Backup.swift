//

import XCTest
import WireTesting
@testable import WireSyncEngine

class SessionManagerTests_Backup: IntegrationTest {
    
    override var useInMemoryStore: Bool {
        return false
    }
    
    private var backupURL: URL!
    private var unzippedURL: URL!
    
    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
        createExtraUsersAndConversations()
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        backupURL = directory.appendingPathComponent("BackupTests")
        unzippedURL = directory.appendingPathComponent("BackupTests_Unzipped")

        do {
            try FileManager.default.createDirectory(atPath: backupURL.path, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(atPath: unzippedURL.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Unable to create directories: \(error)")
        }
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.removeItem(at: unzippedURL)
        backupURL = nil
        unzippedURL = nil
        super.tearDown()
    }
    
    private func createTemporaryURL() -> URL {
        return backupURL.appendingPathComponent(UUID().uuidString)
    }
    
    func testThatItReturnsAnErrorWhenThereIsNoSelectedAccount() {
        let result = backupActiveAcount(password: name)
        XCTAssertEqual(result.error as? SessionManager.BackupError, .noActiveAccount)
    }
    
    func testThatItCreatesABackupIncludingMetadataAndZipsIt() throws {
        // Given
        XCTAssert(login())
        
        // When
        let result = backupActiveAcount(password: "12345678")
        guard let url = result.value else { return XCTFail("\(result.error!)") }
        
        let decryptedURL = createTemporaryURL()
        let moc = sessionManager!.activeUserSession!.managedObjectContext!
        try SessionManager.decrypt(from: url, to: decryptedURL, password: "12345678", accountId: ZMUser.selfUser(in: moc).remoteIdentifier!)
        
        guard decryptedURL.unzip(to: unzippedURL) else { return XCTFail("Decompression failed") }
        
        // Then
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let expectedName = "Wire-\(self.selfUser!.handle!)-Backup_\(formatter.string(from: .init())).ios_wbu"
        
        XCTAssertEqual(url.lastPathComponent, expectedName)
        let dataURL = unzippedURL.appendingPathComponent("data")
        let metadataURL = unzippedURL.appendingPathComponent("export.json")
        let metadata = try BackupMetadata(url: metadataURL)
        
        XCTAssertEqual(metadata.platform, .iOS)
        XCTAssertEqual(metadata.appVersion, Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        XCTAssertEqual(metadata.userIdentifier, sessionManager?.accountManager.selectedAccount?.userIdentifier)
        XCTAssert(FileManager.default.fileExists(atPath: dataURL.path))
    }

    func testThatItReturnsAnErrorWhenUserIsNotAuthenticated() {
        sessionManager?.logoutCurrentSession()
        let result = restoreAcount(password: name, from: createTemporaryURL())
        XCTAssertEqual(result.error as? SessionManager.BackupError, .notAuthenticated)
    }
    
    func testThatItImportsAZippedBackup() throws {
        // Given
        XCTAssert(login())
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        
        let backupResult = backupActiveAcount(password: name)
        guard let url = backupResult.value else { return XCTFail("\(backupResult.error!)") }
        
        let moc = sessionManager!.activeUserSession!.managedObjectContext!
        let userId = ZMUser.selfUser(in: moc).remoteIdentifier!
        let accountFolder = StorageStack.accountFolder(accountIdentifier: userId, applicationContainer: sharedContainer)
        let fm = FileManager.default
        try fm.removeItem(at: accountFolder)
        let storePath = accountFolder.appendingPathComponent("store").path
        XCTAssertFalse(fm.fileExists(atPath: storePath))
        
        // When
        let result = restoreAcount(password: name, from: url)
        
        // Then
        XCTAssertNil(result.error, "\(result.error!)")
        XCTAssert(fm.fileExists(atPath: storePath))
    }
    
    func testThatItReturnsAnErrorWhenImportingFileWithWrongPathExtension() throws {
        // Given
        XCTAssert(login())
        
        try FileManager.default.createDirectory(atPath: backupURL.path, withIntermediateDirectories: true, attributes: nil)
        let dataURL = backupURL.appendingPathComponent("invalid_backup.zip")
        let randomData = Data.secureRandomData(length: 1024)
        try randomData.write(to: dataURL)
        let encryptedURL = createTemporaryURL()
        let moc = sessionManager!.activeUserSession!.managedObjectContext!
        try SessionManager.encrypt(from: dataURL, to: encryptedURL, password: "notsorandom", accountId: ZMUser.selfUser(in: moc).remoteIdentifier!)

        // When
        let result = restoreAcount(password: "notsorandom", from: encryptedURL)
        
        // Then
        XCTAssertEqual(result.error as? SessionManager.BackupError, .invalidFileExtension)
    }
    
    func testThatItReturnsAnErrorWhenImportingFileWithWrongPassword() throws {
        // Given
        XCTAssert(login())
        guard let sharedContainer = Bundle.main.appGroupIdentifier.map(FileManager.sharedContainerDirectory) else { return XCTFail() }
        
        let backupResult = backupActiveAcount(password: "correctpassword")
        guard let url = backupResult.value else { return XCTFail("\(backupResult.error!)") }
        
        let moc = sessionManager!.activeUserSession!.managedObjectContext!
        let userId = ZMUser.selfUser(in: moc).remoteIdentifier!
        let accountFolder = StorageStack.accountFolder(accountIdentifier: userId, applicationContainer: sharedContainer)
        let fm = FileManager.default
        try fm.removeItem(at: accountFolder)
        let storePath = accountFolder.appendingPathComponent("store").path
        XCTAssertFalse(fm.fileExists(atPath: storePath))
        
        // When
        guard let error = restoreAcount(password: "wrongpassword!!11!", from: url).error else { return XCTFail("no error thrown") }
     
        // Then
        guard case SessionManager.BackupError.decryptionError = error else { return XCTFail("wrong error: \(error)") }
    }
    
    func testThatItDeletesABackup() {
        // Given
        XCTAssert(login())
        
        let result = backupActiveAcount(password: "idontneednopassword")
        guard let url = result.value else { return XCTFail("\(result.error!)") }
        XCTAssertNil(restoreAcount(password: "idontneednopassword", from: url).error)
        XCTAssert(FileManager.default.fileExists(atPath: StorageStack.backupsDirectory.path))
        XCTAssert(FileManager.default.fileExists(atPath: StorageStack.importsDirectory.path))
        
        // When
        SessionManager.clearPreviousBackups(dispatchGroup: dispatchGroup)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.2))
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: StorageStack.backupsDirectory.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: StorageStack.importsDirectory.path))
    }
    
    func DISABLED_testThatItDeletesOldEphemeralMessagesWhenRestoringFromABackup() {
        // Given
        XCTAssert(login())
        
        let nonce = UUID.create()
        
        do {
            let conversation = self.conversation(for: selfToUser1Conversation)!
            conversation.messageDestructionTimeout = .local(0.5)
            let moc = sessionManager!.activeUserSession!.managedObjectContext!
            
            let message = conversation.append(text: "foo") as! ZMClientMessage
            message.nonce = nonce
            message.sender = ZMUser.insertNewObject(in: moc)
            message.sender?.remoteIdentifier = .create()
            XCTAssert(message.startSelfDestructionIfNeeded())
            XCTAssertNotNil(message.destructionDate)
            XCTAssertNotNil(message.textMessageData?.messageText)
            XCTAssertNotNil(message.sender)
            XCTAssert(moc.saveOrRollback())
            XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        }
        
        // When
        let result = backupActiveAcount(password: "12345678")
        guard let url = result.value else { return XCTFail("backup failed") }
        deleteAuthenticationCookie()
        recreateSessionManagerAndDeleteLocalData()
        XCTAssert(login())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let restoreResult = restoreAcount(password: "12345678", from: url)
        guard nil == restoreResult.error else { return XCTFail("\(result.error!)") }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssert(login())
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        spinMainQueue(withTimeout: 2)
        
        // Then
        XCTAssert(wait(withTimeout: 5) {
            guard let moc = self.sessionManager?.activeUserSession?.managedObjectContext else { return false }
            guard let conversation = self.conversation(for: self.selfToUser1Conversation) else { return false }
            let message = ZMMessage.fetch(withNonce: nonce, for: conversation, in: moc)
            return nil == message?.textMessageData?.messageText && nil == message?.sender
        })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
    
    // MARK: - Helper
    
    private func backupActiveAcount(
        password: String,
        file: StaticString = #file,
        line: UInt = #line
        ) -> Result<URL> {

        var result: Result<URL> = .failure(TestError.uninitialized)
        sessionManager?.backupActiveAccount(password: password) { result = $0 }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5), file: file, line: line)
        return result
    }
    
    private func restoreAcount(
        password: String,
        from url: URL,
        file: StaticString = #file,
        line: UInt = #line
        ) -> VoidResult {
        
        var result: VoidResult = .failure(TestError.uninitialized)
        sessionManager?.restoreFromBackup(at: url, password: password) { result = $0 }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        return result
    }
    
}

private enum TestError: Error {
    case uninitialized
}
