//

import XCTest
@testable import WireSyncEngine

class ZMLocalNotificationTests_ExpiredMessage: MessagingTest {
    
    var userWithNoName: ZMUser!
    var userWithName: ZMUser!
    var otherUser: ZMUser!
    var oneOnOneConversation: ZMConversation!
    var groupConversation: ZMConversation!
    var groupConversationWithoutName: ZMConversation!
    
    override func setUp() {
        super.setUp()
        
        syncMOC.performGroupedBlockAndWait {
            ZMUser.selfUser(in: self.syncMOC).remoteIdentifier = UUID.create()
            
            self.userWithName = ZMUser.insertNewObject(in: self.syncMOC)
            self.userWithName.name = "Karl"
            
            self.userWithNoName = ZMUser.insertNewObject(in: self.syncMOC)
            
            self.otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            self.otherUser.name = "Bob"
            
            self.oneOnOneConversation = ZMConversation.insertNewObject(in: self.syncMOC)
            self.oneOnOneConversation.remoteIdentifier = UUID.create()
            self.oneOnOneConversation.conversationType = .oneOnOne
            
            self.groupConversation = ZMConversation.insertNewObject(in: self.syncMOC)
            self.groupConversation.remoteIdentifier = UUID.create()
            self.groupConversation.userDefinedName = "This is a group conversation"
            self.groupConversation.conversationType = .group
            
            self.groupConversationWithoutName = ZMConversation.insertNewObject(in: self.syncMOC)
            self.groupConversationWithoutName.remoteIdentifier = UUID.create()
            self.groupConversationWithoutName.conversationType = .group
            
            self.syncMOC.saveOrRollback()
        }
    }
    
    override func tearDown() {
        userWithNoName = nil
        userWithName = nil
        oneOnOneConversation = nil
        groupConversation = nil
        groupConversationWithoutName = nil
        super.tearDown()
    }
    
    func testThatItSetsTheConversationOnTheNotification() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let message = ZMMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            self.oneOnOneConversation.mutableMessages.add(message)
            
            // when
            let note = ZMLocalNotification(expiredMessage: message)
            
            // then
            XCTAssertNotNil(note)
            let conversation = note!.conversation(in: message.managedObjectContext!)
            XCTAssertEqual(conversation, self.oneOnOneConversation)
        }
    }

    func testThatItSetsTheConversationOnTheNotification_InitWithConversation() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let message = ZMMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            self.oneOnOneConversation.mutableMessages.add(message)
            
            // when
            let note = ZMLocalNotification(expiredMessageIn: message.conversation!)
            
            // then
            XCTAssertNotNil(note)
            let conversation = note!.conversation(in: message.managedObjectContext!)
            XCTAssertEqual(conversation, self.oneOnOneConversation)
        }
    }
    
    func testThatItCreatesANotificationWithTheRightTextForFailedMessageInGroupConversation() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let message = ZMMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            self.groupConversation.mutableMessages.add(message)
            
            // when
            let note = ZMLocalNotification(expiredMessage: message)
            
            // then
            XCTAssertNotNil(note)
            XCTAssertEqual(note!.title, self.groupConversation.userDefinedName)
            XCTAssertEqual(note!.body, "Unable to send a message")
        }
    }
    
    func testThatItCreatesANotificationWithTheRightTextForFailedMessageInGroupConversation_NoConversationName() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let message = ZMMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            self.groupConversationWithoutName.mutableMessages.add(message)
            
            // when
            let note = ZMLocalNotification(expiredMessage: message)
            
            // then
            XCTAssertNotNil(note)
            XCTAssertNil(note!.title)
            XCTAssertEqual(note!.body, "Unable to send a message")
        }
    }
    
    func testThatItCreatesANotificationWithTheRightTextForFailedMessageInOneOnOneConversation() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let message = ZMMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            self.oneOnOneConversation.mutableMessages.add(message)
            let connection = ZMConnection.insertNewObject(in: self.syncMOC)
            connection.conversation = self.oneOnOneConversation
            connection.to = self.userWithName
            
            // when
            let note = ZMLocalNotification(expiredMessage: message)
            
            // then
            XCTAssertNotNil(note)
            XCTAssertEqual(note!.title, self.userWithName.displayName)
            XCTAssertEqual(note!.body, "Unable to send a message")
        }
    }
    
    func testThatItCreatesANotificationWithTheRightTextForFailedMessageInOneOnOneConversation_NoUserName() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let message = ZMMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            self.oneOnOneConversation.mutableMessages.add(message)
            let connection = ZMConnection.insertNewObject(in: self.syncMOC)
            connection.conversation = self.oneOnOneConversation
            connection.to = self.userWithNoName
            
            // when
            let note = ZMLocalNotification(expiredMessage: message)
            
            // then
            XCTAssertNotNil(note)
            XCTAssertNil(note!.title)
            XCTAssertEqual(note!.body, "Unable to send a message")
        }
    }
    
}
