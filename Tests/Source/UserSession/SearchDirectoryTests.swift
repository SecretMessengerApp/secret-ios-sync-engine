//

import Foundation

@testable import WireSyncEngine

class SearchDirectoryTests : MessagingTest {

    func testThatItEmptiesTheSearchUserCacheOnTeardown() {
        // given
        uiMOC.zm_searchUserCache = NSCache()
        let uuid = UUID.create()
        let sut = SearchDirectory(userSession: mockUserSession)
        _ = ZMSearchUser(contextProvider: mockUserSession, name: "John Doe", handle: "john", accentColor: .brightOrange, remoteIdentifier: uuid)
        XCTAssertNotNil(uiMOC.zm_searchUserCache?.object(forKey: uuid as NSUUID))
    
        // when
        sut.tearDown()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertNil(uiMOC.zm_searchUserCache?.object(forKey: uuid as NSUUID))
    }
    
}
