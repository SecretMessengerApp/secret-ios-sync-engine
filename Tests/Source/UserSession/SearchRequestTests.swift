//

import Foundation

@testable import WireSyncEngine

class SearchRequestTests : MessagingTest {
    
    func testThatItTruncatesTheQuery() {
        // given
        let croppedString = "f".padding(toLength: 200, withPad: "o", startingAt: 0)
        let tooLongString = "f".padding(toLength: 300, withPad: "o", startingAt: 0)
        
        // when
        let request = SearchRequest(query: tooLongString, searchOptions: [])
        
        // then
        XCTAssertEqual(request.query, croppedString)
    }
    
    func testThatItNormalizesTheQuery() {
        // given
        let query = "Ã.b.ć "
        
        // when
        let request = SearchRequest(query: query, searchOptions: [])
        
        // then
        XCTAssertEqual(request.normalizedQuery, "abc")
    }
    
}
