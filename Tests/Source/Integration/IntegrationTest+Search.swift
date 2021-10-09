//

import WireMockTransport
import XCTest
import WireTesting

extension IntegrationTest {
    
    @objc
    public func searchAndConnectToUser(withName name: String, searchQuery: String) {
        createSharedSearchDirectory()
        
        let searchCompleted = expectation(description: "Search result arrived")
        let request = SearchRequest(query: searchQuery, searchOptions: [.directory])
        let task = sharedSearchDirectory?.perform(request)
        var searchResult : SearchResult? = nil
        
        task?.onResult { (result, completed) in
            if completed {
                searchResult = result
                searchCompleted.fulfill()
            }
        }
        
        task?.start()
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertNotNil(searchResult)
        
        let searchUser = searchResult?.directory.first
        XCTAssertNotNil(searchUser)
        XCTAssertEqual(searchUser?.name, name)
        
        searchUser?.connect(message: "Hola")
    }
    
    @objc
    public func searchForDirectoryUser(withName name: String, searchQuery: String) -> ZMSearchUser? {
        createSharedSearchDirectory()
        
        let searchCompleted = expectation(description: "Search result arrived")
        let request = SearchRequest(query: searchQuery, searchOptions: [.directory])
        let task = sharedSearchDirectory?.perform(request)
        var searchResult : SearchResult? = nil
        
        task?.onResult { (result, completed) in
            if completed {
                searchResult = result
                searchCompleted.fulfill()
            }
        }
        
        task?.start()
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertNotNil(searchResult)
        
        return searchResult?.directory.first
    }
    
    @objc
    public func searchForConnectedUser(withName name: String, searchQuery: String) -> ZMUser? {
        createSharedSearchDirectory()
        
        let searchCompleted = expectation(description: "Search result arrived")
        let request = SearchRequest(query: searchQuery, searchOptions: [.contacts])
        let task = sharedSearchDirectory?.perform(request)
        var searchResult : SearchResult? = nil
        
        task?.onResult { (result, completed) in
            if completed {
                searchResult = result
                searchCompleted.fulfill()
            }
        }
        
        task?.start()
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        XCTAssertNotNil(searchResult)
        
        return searchResult?.contacts.first
    }
    
    @objc
    public func connect(withUser user: UserType) {
        userSession?.performChanges {
            user.connect(message: "Hola")
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
    
}
