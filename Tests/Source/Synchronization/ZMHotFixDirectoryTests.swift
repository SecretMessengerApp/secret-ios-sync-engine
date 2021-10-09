////

import Foundation

import WireTesting
@testable import WireSyncEngine

class ZMHotFixDirectoryTests: MessagingTest {
    
    func testThatOnlyTeamConversationsAreUpdated() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let g1 = ZMConversation.insertNewObject(in: self.syncMOC)
            g1.conversationType = .group
            XCTAssertFalse(g1.needsToBeUpdatedFromBackend)
            
            let g2 = ZMConversation.insertNewObject(in: self.syncMOC)
            g2.conversationType = .group
            g2.team = Team.insertNewObject(in: self.syncMOC)
            XCTAssertFalse(g2.needsToBeUpdatedFromBackend)
            
            // when
            ZMHotFixDirectory.refetchTeamGroupConversations(self.syncMOC)
            
            // then
            XCTAssertFalse(g1.needsToBeUpdatedFromBackend)
            XCTAssertTrue(g2.needsToBeUpdatedFromBackend)
        }
    }
    
    func testThatOnlyGroupTeamConversationsAreUpdated() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let team = Team.insertNewObject(in: self.syncMOC)
            
            let c1 = ZMConversation.insertNewObject(in: self.syncMOC)
            c1.conversationType = .oneOnOne
            c1.team = team
            XCTAssertFalse(c1.needsToBeUpdatedFromBackend)
            
            let c2 = ZMConversation.insertNewObject(in: self.syncMOC)
            c2.conversationType = .connection
            c2.team = team
            XCTAssertFalse(c2.needsToBeUpdatedFromBackend)
            
            
            let c3 = ZMConversation.insertNewObject(in: self.syncMOC)
            c3.conversationType = .group
            c3.team = team
            XCTAssertFalse(c3.needsToBeUpdatedFromBackend)
            
            // when
            ZMHotFixDirectory.refetchTeamGroupConversations(self.syncMOC)
            
            // then
            XCTAssertFalse(c1.needsToBeUpdatedFromBackend)
            XCTAssertFalse(c2.needsToBeUpdatedFromBackend)
            XCTAssertTrue(c3.needsToBeUpdatedFromBackend)
        }
    }
    
    func testThatOnlyGroupConversationsWhereSelfUserIsAnActiveParticipantAreUpdated() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            
            let c1 = ZMConversation.insertNewObject(in: self.syncMOC)
            c1.conversationType = .oneOnOne
            XCTAssertFalse(c1.needsToBeUpdatedFromBackend)
            
            let c2 = ZMConversation.insertNewObject(in: self.syncMOC)
            c2.conversationType = .connection
            XCTAssertFalse(c2.needsToBeUpdatedFromBackend)
            
            let c3 = ZMConversation.insertNewObject(in: self.syncMOC)
            c3.conversationType = .group
            XCTAssertFalse(c3.needsToBeUpdatedFromBackend)
            
            let c4 = ZMConversation.insertNewObject(in: self.syncMOC)
            c4.conversationType = .group
            c4.mutableLastServerSyncedActiveParticipants.add(selfUser)
            XCTAssertFalse(c4.needsToBeUpdatedFromBackend)
            
            // when
            ZMHotFixDirectory.refetchGroupConversations(self.syncMOC)
            
            // then
            XCTAssertFalse(c1.needsToBeUpdatedFromBackend)
            XCTAssertFalse(c2.needsToBeUpdatedFromBackend)
            XCTAssertFalse(c3.needsToBeUpdatedFromBackend)
            XCTAssertTrue(c4.needsToBeUpdatedFromBackend)
        }
    }
    
    func testThatAllNewConversationSystemMessagesAreMarkedAsRead_WhenConversationWasNeverRead() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let timestamp = Date()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .group
            conversation.appendNewConversationSystemMessage(at: timestamp, users: [])
            XCTAssertEqual(conversation.unreadMessages.count, 1)
            
            // when
            ZMHotFixDirectory.markAllNewConversationSystemMessagesAsRead(self.syncMOC)
            
            // then
            XCTAssertEqual(conversation.unreadMessages.count, 0)
        }
    }
    
    func testThatAllNewConversationSystemMessagesAreMarkedAsRead_WhenConversationWasReadEarlier() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let timestamp = Date()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .group
            conversation.appendNewConversationSystemMessage(at: timestamp, users: [])
            conversation.lastReadServerTimeStamp = timestamp.addingTimeInterval(-1)
            XCTAssertEqual(conversation.unreadMessages.count, 1)
            
            // when
            ZMHotFixDirectory.markAllNewConversationSystemMessagesAsRead(self.syncMOC)
            
            // then
            XCTAssertEqual(conversation.unreadMessages.count, 0)
        }
    }
    
    func testThatAllNewConversationSystemMessagesAreMarkedAsRead_ButNotAnythingAfter() {
        syncMOC.performGroupedBlockAndWait {
            
            // given
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = UUID()
            let timestamp = Date()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .group
            conversation.appendNewConversationSystemMessage(at: timestamp, users: [])
            let message = conversation.append(text: "Hello") as? ZMClientMessage
            message?.sender = user
            conversation.lastReadServerTimeStamp = timestamp.addingTimeInterval(-1)
            XCTAssertEqual(conversation.unreadMessages.count, 2)
            
            // when
            ZMHotFixDirectory.markAllNewConversationSystemMessagesAsRead(self.syncMOC)
            
            // then
            XCTAssertEqual(conversation.unreadMessages.count, 1)
        }
    }
    
}
