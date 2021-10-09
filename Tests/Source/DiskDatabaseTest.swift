//


import Foundation
import XCTest
import WireTesting
import WireDataModel

public class DiskDatabaseTest: ZMTBaseTest {
    var sharedContainerURL : URL!
    var accountId : UUID!
    var moc: NSManagedObjectContext {
        return contextDirectory.uiContext
    }
    var contextDirectory: ManagedObjectContextDirectory!
    
    var storeURL : URL {
        return StorageStack.accountFolder(
            accountIdentifier: accountId,
            applicationContainer: sharedContainerURL
            ).appendingPersistentStoreLocation()
    }
    
    public override func setUp() {
        super.setUp()

        accountId = .create()
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let groupIdentifier = "group." + bundleIdentifier!
        sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
        cleanUp()
        createDatabase()

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 1))
        XCTAssert(FileManager.default.fileExists(atPath: storeURL.path))
    }
    
    public override func tearDown() {
        cleanUp()
        contextDirectory = nil
        sharedContainerURL = nil
        accountId = nil
        super.tearDown()
    }
    
    private func createDatabase() {
        StorageStack.reset()
        StorageStack.shared.createStorageAsInMemory = false

        let expectation = self.expectation(description: "Created context")
        StorageStack.shared.createManagedObjectContextDirectory(accountIdentifier: accountId, applicationContainer: storeURL, dispatchGroup: self.dispatchGroup) {
            self.contextDirectory = $0
            expectation.fulfill()
        }
        XCTAssert(waitForCustomExpectations(withTimeout: 0.5))
        self.moc.performGroupedBlockAndWait {
            let selfUser = ZMUser.selfUser(in: self.moc)
            selfUser.remoteIdentifier = self.accountId
        }
    }
    
    private func cleanUp() {
        try? FileManager.default.contentsOfDirectory(at: sharedContainerURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).forEach {
            try? FileManager.default.removeItem(at: $0)
        }

        StorageStack.reset()
    }
}

