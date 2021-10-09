//

import XCTest

class ConversationTests_Confirmation: ConversationTestsBase {
    
    func testThatItSendsAConfirmationWhenReceivingAMessageInAOneOnOneConversation() {
        if (BackgroundAPNSConfirmationStatus.sendDeliveryReceipts) {
            // given
            XCTAssert(login())
            
            let fromClient = user1?.clients.anyObject() as! MockUserClient
            let toClient = selfUser?.clients.anyObject() as! MockUserClient
            let textMessage = ZMGenericMessage.message(content: ZMText.text(with: "Hello"))
            let conversation = self.conversation(for: selfToUser1Conversation!)
            
            let requestPath = "/conversations/\(conversation!.remoteIdentifier!.transportString())/otr/messages?report_missing=\(user1!.identifier)"
            
            // expect
            mockTransportSession?.responseGeneratorBlock = { request in
                if (request.path == requestPath) {
                    guard let hiddenMessage = conversation?.hiddenMessages.first as? ZMClientMessage,
                        let message = conversation?.lastMessage as? ZMClientMessage
                        else {
                            XCTFail("Did not insert confirmation message.")
                            return nil
                    }
                    XCTAssertTrue(hiddenMessage.genericMessage!.hasConfirmation())
                    XCTAssertEqual(hiddenMessage.genericMessage!.confirmation.firstMessageId, message.nonce!.transportString())
                }
                return nil
            }
            
            // when
            mockTransportSession?.performRemoteChanges { session in
                self.selfToUser1Conversation?.encryptAndInsertData(from: fromClient, to: toClient, data: textMessage.data())
            }
            XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
            
            // then
            XCTAssertEqual(conversation?.allMessages.count, 2) // system message & inserted message
            
            guard let request = mockTransportSession?.receivedRequests().last else {return XCTFail()}
            XCTAssertEqual((request as AnyObject).path, requestPath)
            
            XCTAssertEqual(conversation?.lastModifiedDate, conversation?.lastMessage?.serverTimestamp)
        }
    }
    
    func testThatItSetsAMessageToDeliveredWhenReceivingNewMessagesInAOneOnOneConversation() {
        if (BackgroundAPNSConfirmationStatus.sendDeliveryReceipts) {
            // given
            
            XCTAssert(login())
            
            let fromClient = user1?.clients.anyObject() as! MockUserClient
            let toClient = selfUser?.clients.anyObject() as! MockUserClient
            let conversation = self.conversation(for: selfToUser1Conversation!)
            let requestPath = "/conversations/\(conversation!.remoteIdentifier!.transportString())/otr/messages?report_missing=\(user1!.identifier)"
            
            
            // expect
            mockTransportSession?.responseGeneratorBlock = { request in
                if (request.path == requestPath) {

                    guard let conversation = conversation, let hiddenMessage = conversation.hiddenMessages.first(where: { (item) -> Bool in
                            return (item as? ZMClientMessage)?.genericMessage!.confirmation.moreMessageIds != nil
                    }) as? ZMClientMessage else { return nil }
                    
                    var nonces = Set(conversation.allMessages.compactMap { $0.nonce?.transportString() })
                    XCTAssertTrue(hiddenMessage.genericMessage!.hasConfirmation())
                    XCTAssertNotNil(nonces.remove(hiddenMessage.genericMessage!.confirmation.firstMessageId))
                    XCTAssertNotNil(hiddenMessage.genericMessage!.confirmation.moreMessageIds)
                    let moreMessageIds = Set(hiddenMessage.genericMessage!.confirmation.moreMessageIds! as! [String])
                    XCTAssertTrue(moreMessageIds.isSubset(of: nonces))
                    
                }
                return nil
            }
            
            // when
            performIgnoringZMLogError {
             
                self.mockTransportSession?.performRemoteChanges { session in
                    session.simulatePushChannelClosed()
                    let textMessage1 = ZMGenericMessage.message(content: ZMText.text(with: "Hello!"), nonce: UUID())
                    self.selfToUser1Conversation?.encryptAndInsertData(from: fromClient, to: toClient, data: textMessage1.data())
                    self.spinMainQueue(withTimeout: 0.2)
                    let textMessage2 = ZMGenericMessage.message(content: ZMText.text(with: "It's me!"), nonce: UUID())
                    self.selfToUser1Conversation?.encryptAndInsertData(from: fromClient, to: toClient, data: textMessage2.data())
                    session.simulatePushChannelOpened()
                }
                XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
            }
            
            // then
            XCTAssertEqual(conversation?.allMessages.count, 3) // system message & inserted message
            
            guard let request = mockTransportSession?.receivedRequests().last else {return XCTFail()}
            XCTAssertEqual((request as AnyObject).path, requestPath)
            
            // We should confirm all message deliveries with one message
            XCTAssertEqual(mockTransportSession.receivedRequests().filter({ $0.method == ZMTransportRequestMethod.methodPOST && $0.path.contains("conversations/")}).count, 1)
            
            XCTAssertEqual(conversation?.lastModifiedDate, conversation?.lastMessage?.serverTimestamp)
        }
    }
    
    func testThatItSetsAMessageToDeliveredWhenReceivingAConfirmationMessageInAOneOnOneConversation() {
        if (BackgroundAPNSConfirmationStatus.sendDeliveryReceipts) {
            
            // given
            XCTAssert(login())
            
            let conversation = self.conversation(for: selfToUser1Conversation!)
            var message : ZMClientMessage!
            self.userSession?.performChanges {
                message = conversation?.append(text: "Hello") as? ZMClientMessage
            }
            XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
            XCTAssertEqual(message.deliveryState, ZMDeliveryState.sent)
            
            let fromClient = user1?.clients.anyObject() as! MockUserClient
            let toClient = selfUser?.clients.anyObject() as! MockUserClient
            let confirmationMessage = ZMGenericMessage.message(content: ZMConfirmation.confirm(messageId: message.nonce!))
            
            // when
            mockTransportSession?.performRemoteChanges { session in
                self.selfToUser1Conversation?.encryptAndInsertData(from: fromClient, to: toClient, data: confirmationMessage.data())
            }
            XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
            
            // then
            // The confirmation message is not inserted
            XCTAssertEqual(conversation?.hiddenMessages.count, 0)
            XCTAssertEqual(message.deliveryState, ZMDeliveryState.delivered)
            
            XCTAssertEqual(conversation?.lastModifiedDate, message.serverTimestamp)
        }
    }
    
    func testThatItSendsANotificationWhenUpdatingTheDeliveryState() {
        guard BackgroundAPNSConfirmationStatus.sendDeliveryReceipts else { return }
        // given
        XCTAssert(login())

        let conversation = self.conversation(for: selfToUser1Conversation!)
        var message : ZMClientMessage!
        self.userSession?.performChanges {
            message = conversation?.append(text: "Hello") as? ZMClientMessage
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        XCTAssertEqual(conversation?.hiddenMessages.count, 0)
        XCTAssertEqual(message.deliveryState, ZMDeliveryState.sent)

        let fromClient = user1!.clients.anyObject() as! MockUserClient
        let toClient = selfUser!.clients.anyObject() as! MockUserClient
        let confirmationMessage = ZMGenericMessage.message(content: ZMConfirmation.confirm(messageId: message.nonce!))

        let convObserver = ConversationChangeObserver(conversation: conversation)

        let messageObserver = MessageChangeObserver(message: message)

        // when
        mockTransportSession?.performRemoteChanges { session in
            self.selfToUser1Conversation?.encryptAndInsertData(from: fromClient, to: toClient, data: confirmationMessage.data())
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))

        // then
        if convObserver!.notifications.count > 0 {
            return XCTFail()
        }
        guard let messageChangeInfo = messageObserver?.notifications.firstObject  as? MessageChangeInfo else {
            return XCTFail()
        }
        XCTAssertTrue(messageChangeInfo.deliveryStateChanged)
    }
}

