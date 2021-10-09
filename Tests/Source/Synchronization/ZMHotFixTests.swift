////

import Foundation

class ZMHotFixTests_Integration: MessagingTest {

    func testThatAllConversationsAreUpdated_198_0_0() {
        var g1: ZMConversation!
        var g2: ZMConversation!
        var g3: ZMConversation!
        
        syncMOC.performGroupedAndWait { _ in
            // given
            g1 = ZMConversation.insertNewObject(in: self.syncMOC)
            g1.conversationType = .group
            XCTAssertFalse(g1.needsToBeUpdatedFromBackend)
            
            g2 = ZMConversation.insertNewObject(in: self.syncMOC)
            g2.conversationType = .connection
            g2.team = Team.insertNewObject(in: self.syncMOC)
            XCTAssertFalse(g2.needsToBeUpdatedFromBackend)
            
            g3 = ZMConversation.insertNewObject(in: self.syncMOC)
            g3.conversationType = .connection
            XCTAssertFalse(g3.needsToBeUpdatedFromBackend)
            
            self.syncMOC.setPersistentStoreMetadata("147.0", key: "lastSavedVersion")
            let sut = ZMHotFix(syncMOC: self.syncMOC)
            
            // when
            self.performIgnoringZMLogError {
                sut?.applyPatches(forCurrentVersion: "198.0")
            }
        }
        
        syncMOC.performGroupedAndWait { _ in
            // then
            XCTAssertTrue(g1.needsToBeUpdatedFromBackend)
            XCTAssertTrue(g2.needsToBeUpdatedFromBackend)
            XCTAssertTrue(g3.needsToBeUpdatedFromBackend)
        }
    }
    
    func testThatItRemovesPendingConfirmationsForDeletedMessages_54_0_1() {
        var confirmationMessage: ZMClientMessage! = nil
        syncMOC.performGroupedBlock {
            // GIVEN
            self.syncMOC.setPersistentStoreMetadata("0.1", key: "lastSavedVersion")
            self.syncMOC.setPersistentStoreMetadata(NSNumber(booleanLiteral: true), key: "HasHistory")
            
            let oneOnOneConversation = ZMConversation(context: self.syncMOC)
            oneOnOneConversation.conversationType = .oneOnOne
            oneOnOneConversation.remoteIdentifier = UUID()
            
            let otherUser = ZMUser(context: self.syncMOC)
            otherUser.remoteIdentifier = UUID()
            
            let incomingMessage = oneOnOneConversation.append(text: "Test") as! ZMClientMessage
            let confirmation = ZMConfirmation.confirm(messageId: incomingMessage.nonce!, type: .DELIVERED)
            confirmationMessage = oneOnOneConversation.appendClientMessage(with: ZMGenericMessage.message(content: confirmation), expires: false, hidden: true)
            
            self.syncMOC.saveOrRollback()
            
            XCTAssertNotNil(confirmationMessage)
            XCTAssertFalse(confirmationMessage.isDeleted)
            
            incomingMessage.visibleInConversation = nil
            incomingMessage.hiddenInConversation = oneOnOneConversation
            
            // WHEN
            let sut = ZMHotFix(syncMOC: self.syncMOC)
            self.performIgnoringZMLogError {
                sut!.applyPatches(forCurrentVersion: "54.0.1")
            }
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        syncMOC.performGroupedBlock {
            self.syncMOC.saveOrRollback()
        }
        syncMOC.performGroupedBlock {
            XCTAssertNil(confirmationMessage.managedObjectContext)
        }
    }

    func testThatItUpdatesManagedByPropertyFromUser_From_235_0_0() {
        syncMOC.performGroupedBlock {
            // GIVEN
            self.syncMOC.setPersistentStoreMetadata("235.0.0", key: "lastSavedVersion")
            self.syncMOC.setPersistentStoreMetadata(NSNumber(booleanLiteral: true), key: "HasHistory")

            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            selfUser.needsToBeUpdatedFromBackend = false
            self.syncMOC.saveOrRollback()

            XCTAssertFalse(selfUser.needsToBeUpdatedFromBackend)


            // WHEN
            let sut = ZMHotFix(syncMOC: self.syncMOC)
            self.performIgnoringZMLogError {
                sut!.applyPatches(forCurrentVersion: "235.0.1")
            }
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        syncMOC.performGroupedBlock {
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            XCTAssertTrue(selfUser.needsToBeUpdatedFromBackend)
        }
    }
    
    func testThatItMarksTeamMembersToBeUpdatedFromTheBackend_238_0_0() {
        syncMOC.performGroupedBlock {
            // GIVEN
            self.syncMOC.setPersistentStoreMetadata("238.0.0", key: "lastSavedVersion")
            self.syncMOC.setPersistentStoreMetadata(NSNumber(booleanLiteral: true), key: "HasHistory")
            
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            let team = Team.fetchOrCreate(with: UUID(), create: true, in: self.syncMOC, created: nil)!
            _ = Member.getOrCreateMember(for: selfUser, in: team, context: self.syncMOC)
            team.needsToRedownloadMembers = false
            
            // WHEN
            let sut = ZMHotFix(syncMOC: self.syncMOC)
            self.performIgnoringZMLogError {
                sut!.applyPatches(forCurrentVersion: "238.0.1")
            }
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        syncMOC.performGroupedBlock {
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            XCTAssertTrue(selfUser.team!.needsToRedownloadMembers)
        }
    }
    
    func testThatItMarksLabelsToBeRefetched_280_0_0() {
        syncMOC.performGroupedBlock {
            // GIVEN
            self.syncMOC.setPersistentStoreMetadata("238.0.0", key: "lastSavedVersion")
            self.syncMOC.setPersistentStoreMetadata(NSNumber(booleanLiteral: true), key: "HasHistory")
            
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            selfUser.needsToRefetchLabels = false
            
            // WHEN
            let sut = ZMHotFix(syncMOC: self.syncMOC)
            self.performIgnoringZMLogError {
                sut!.applyPatches(forCurrentVersion: "280.0.1")
            }
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        syncMOC.performGroupedBlock {
            let selfUser = ZMUser.selfUser(in: self.syncMOC)
            XCTAssertTrue(selfUser.needsToRefetchLabels)
        }
    }

}
