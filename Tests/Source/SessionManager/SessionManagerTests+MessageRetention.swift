//

import XCTest
import WireTesting
@testable import WireSyncEngine

class SessionManagerTests_MessageRetention: IntegrationTest {
    
    override func setUp() {
        super.setUp()
        
        createSelfUserAndConversation()
        createExtraUsersAndConversations()
    }
    
    override var useInMemoryStore: Bool {
        return false
    }
    
    func testThatItDeletesMessagesOlderThanTheRetentionLimit() {
        // given
        XCTAssertTrue(login())
        establishSession(with: user2)
                
        remotelyInsert(text: "Hello 1", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        remotelyInsert(text: "Hello 2", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        remotelyInsert(text: "Hello 3", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(conversation(for: groupConversation)?.allMessages.count, 5) // text messages + system messages
        
        // when
        sessionManager?.configuration.messageRetentionInterval = 1
        spinMainQueue(withTimeout: 1)
        sessionManager?.logoutCurrentSession()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertTrue(login())
        
        // then
        XCTAssertEqual(conversation(for: groupConversation)?.allMessages.count, 0)
    }
    
    func testThatItKeepsMessagesNewerThanTheRetentionLimit() {
        // given
        XCTAssertTrue(login())
        establishSession(with: user2)
        
        remotelyInsert(text: "Hello 1", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        remotelyInsert(text: "Hello 2", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        remotelyInsert(text: "Hello 3", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(conversation(for: groupConversation)?.allMessages.count, 5) // text messages + system messages
        
        // when
        sessionManager?.configuration.messageRetentionInterval = 100
        sessionManager?.logoutCurrentSession()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertTrue(login())
        
        // then
        XCTAssertEqual(conversation(for: groupConversation)?.allMessages.count, 5)
    }
    
    func testThatItKeepsMessagesIfThereIsNoRetentionLimit() {
        // given
        XCTAssertTrue(login())
        establishSession(with: user2)
        
        remotelyInsert(text: "Hello 1", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        remotelyInsert(text: "Hello 2", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        remotelyInsert(text: "Hello 3", from: user2.clients.anyObject() as! MockUserClient, into: groupConversation)
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(conversation(for: groupConversation)?.allMessages.count, 5) // text messages + system messages
        
        // when
        sessionManager?.configuration.messageRetentionInterval = nil
        sessionManager?.logoutCurrentSession()
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertTrue(login())
        
        // then
        XCTAssertEqual(conversation(for: groupConversation)?.allMessages.count, 5)
    }
    
}
