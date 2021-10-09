//

import Foundation

class ZMUserSessionRelocationTests : ZMUserSessionTestsBase {

    func testThatItMovesCaches() throws {
        // given
        let oldLocation = FileManager.default.cachesURLForAccount(with: nil, in: self.sut.sharedContainerURL)
        clearFolder(at: oldLocation)
        
        let _ = UserImageLocalCache(location: oldLocation)
        let itemNames = try FileManager.default.contentsOfDirectory(atPath: oldLocation.path)
        XCTAssertTrue(itemNames.count > 0)
        
        // when
        ZMUserSession.moveCachesIfNeededForAccount(with: self.userIdentifier, in: self.sut.sharedContainerURL)
        
        // then
        let newLocation = FileManager.default.cachesURLForAccount(with: self.userIdentifier, in: self.sharedContainerURL)
        let movedItemNames = try FileManager.default.contentsOfDirectory(atPath: newLocation.path)
        XCTAssertTrue(movedItemNames.count > 0)
        itemNames.forEach {
            XCTAssertTrue(movedItemNames.contains($0))
        }
    }
    
    func testWhitelistedFilePersistence() throws {
        
        // given
        let cachesFolder = FileManager.default.cachesURLForAccount(with: nil, in: self.sut.sharedContainerURL)
        clearFolder(at: cachesFolder)
        
        // when
        let fileName = "com.apple.nsurlsessiond"
        let fileUrl = try writeTestFile(name: fileName, at: cachesFolder)
        ZMUserSession.moveCachesIfNeededForAccount(with: self.userIdentifier, in: self.sut.sharedContainerURL)
        
        //then
        let newFolder = FileManager.default.cachesURLForAccount(with: self.userIdentifier, in: self.sharedContainerURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileUrl.path))                                         // tests that the file remains at the same place
        XCTAssertFalse(FileManager.default.fileExists(atPath: newFolder.appendingPathComponent(fileName).path))     // tests that the file was not moved to the account folder
    }
    
    func testMovingOfNonWhitelistedFile() throws {
        
        // given
        let cachesFolder = FileManager.default.cachesURLForAccount(with: nil, in: self.sut.sharedContainerURL)
        clearFolder(at: cachesFolder)
        
        // when
        let fileName = "example"
        let fileUrl = try writeTestFile(name: fileName, at: cachesFolder)
        ZMUserSession.moveCachesIfNeededForAccount(with: self.userIdentifier, in: self.sut.sharedContainerURL)
        
        //then
        let newFolder = FileManager.default.cachesURLForAccount(with: self.userIdentifier, in: self.sharedContainerURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))                                        // tests that the file isn't in the previous place
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFolder.appendingPathComponent(fileName).path))      // tests that the file was moved to the account folder
    }
    
    
    func clearFolder(at location : URL) {
        if FileManager.default.fileExists(atPath: location.path) {
            let items = try! FileManager.default.contentsOfDirectory(at: location, includingPropertiesForKeys:nil)
            items.forEach{ try! FileManager.default.removeItem(at: $0) }
        }
    }
    
    func writeTestFile(name: String, at location: URL) throws -> URL {
        let content = "ZMUserSessionTest"
        let newLocation = location.appendingPathComponent(name)
        try content.write(to: newLocation, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newLocation.path))
        return newLocation
    }
}
