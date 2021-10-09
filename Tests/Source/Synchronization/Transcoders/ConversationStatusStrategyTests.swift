// 



class ConversationStatusStrategyTests: MessagingTest {
    var sut : ConversationStatusStrategy!
    var selfConversation : ZMConversation!
    
    override func setUp() {
        super.setUp()

        let syncSelfUser =  ZMUser.selfUser(in: self.syncMOC)
        syncSelfUser.remoteIdentifier = UUID.create()
        selfConversation = ZMConversation.insertNewObject(in: self.syncMOC)
        selfConversation.remoteIdentifier = syncSelfUser.remoteIdentifier
        
        sut = ConversationStatusStrategy(managedObjectContext: self.syncMOC)
    }
    
    override func tearDown(){
        sut.tearDown()
        sut = nil
        super.tearDown()
    }

    func testThatItProcessesConversationsWithLocalModifications_LastRead() {
    
        self.syncMOC.performGroupedBlockAndWait{
            // given
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.lastReadServerTimeStamp = Date()
            conversation.remoteIdentifier = UUID.create()
            conversation.setLocallyModifiedKeys(Set(arrayLiteral: "lastReadServerTimeStamp"))
            
            XCTAssertEqual(self.selfConversation.allMessages.count, 0)

            // when
            self.sut.objectsDidChange(Set(arrayLiteral: conversation))
            
            // then
            XCTAssertEqual(self.selfConversation.allMessages.count, 1)
            guard let message = self.selfConversation.lastMessage as? ZMClientMessage else {
                XCTFail("should insert message into self conversation")
                return
            }
            XCTAssertTrue(message.genericMessage!.hasLastRead())
        }
    }
    
    func testThatItProcessesConversationsWithLocalModifications_Cleared() {
        
        self.syncMOC.performGroupedBlockAndWait{
            // given
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.clearedTimeStamp = Date()
            conversation.remoteIdentifier = UUID.create()
            conversation.setLocallyModifiedKeys(Set(arrayLiteral: "clearedTimeStamp"))
            
            XCTAssertEqual(self.selfConversation.allMessages.count, 0)

            // when
            self.sut.objectsDidChange(Set(arrayLiteral: conversation))
            
            // then
            XCTAssertEqual(self.selfConversation.allMessages.count, 1)
            guard let message = self.selfConversation.lastMessage as? ZMClientMessage else {
                XCTFail("should insert message into self conversation")
                return
            }
            XCTAssertTrue(message.genericMessage!.hasCleared())
        }
    }
    
    func testThatItDeletesOlderMessages_Cleared() {
        
        self.syncMOC.performGroupedBlockAndWait{
            // given
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.clearedTimeStamp = Date()
            conversation.remoteIdentifier = UUID.create()
            conversation.setLocallyModifiedKeys(Set(arrayLiteral: "clearedTimeStamp"))
            
            let message = ZMMessage(nonce: UUID(), managedObjectContext: self.syncMOC)
            message.serverTimestamp = conversation.clearedTimeStamp
            message.visibleInConversation = conversation
            
            XCTAssertFalse(conversation.lastMessage!.isDeleted)

            // when
            self.sut.objectsDidChange(Set(arrayLiteral: conversation))
            
            // then
            XCTAssertTrue(message.isZombieObject)
        }
    }
    
    func testThatItAddsUnsyncedConversationsToTrackedObjects() {
        self.syncMOC.performGroupedBlockAndWait{
            // given
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.lastReadServerTimeStamp = Date()
            conversation.remoteIdentifier = UUID.create()
            conversation.setLocallyModifiedKeys(Set(arrayLiteral: "lastReadServerTimeStamp"))
            
            XCTAssertEqual(self.selfConversation.allMessages.count, 0)
            
            // when
            let request = self.sut.fetchRequestForTrackedObjects()
            let result = self.syncMOC.executeFetchRequestOrAssert(request) as! [NSManagedObject]
            if (result.count > 0) {
                self.sut.addTrackedObjects(Set<NSManagedObject>(result))
            } else {
                XCTFail("should fetch insertedConversation")
            }
            
            // then
            XCTAssertEqual(self.selfConversation.allMessages.count, 1)
            guard let message = self.selfConversation.lastMessage as? ZMClientMessage else {
                XCTFail("should insert message into self conversation")
                return
            }
            XCTAssertTrue(message.genericMessage!.hasLastRead())
        }

    }
}

