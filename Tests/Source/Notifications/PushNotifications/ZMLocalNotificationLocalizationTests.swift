//

import XCTest
@testable import WireSyncEngine

class ZMLocalNotificationLocalizationTests: ZMLocalNotificationTests {
    
    func testThatItLocalizesCallkitCallerName() {
        
        let result: (ZMUser, ZMConversation) -> String = {
            $1.localizedCallerName(with: $0)
        }
        
        // then
        XCTAssertEqual(result(sender, groupConversation), "Super User in Super Conversation")
        XCTAssertEqual(result(userWithNoName, groupConversationWithoutName), "Someone calling in a conversation")
        XCTAssertEqual(result(userWithNoName, groupConversation), "Someone calling in Super Conversation")
        XCTAssertEqual(result(sender, groupConversationWithoutName), "Super User calling in a conversation")
    }
}
