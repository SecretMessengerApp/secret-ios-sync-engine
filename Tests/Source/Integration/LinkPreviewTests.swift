//

import Foundation

class LinkPreviewTests: ConversationTestsBase {
    
    var mockLinkPreviewDetector: MockLinkPreviewDetector!
    
    override func setUp() {
        super.setUp()
        
        mockLinkPreviewDetector = MockLinkPreviewDetector()
        
        LinkPreviewDetectorHelper.setTest_debug_linkPreviewDetector(mockLinkPreviewDetector)
    }
    
    override func tearDown() {
        mockLinkPreviewDetector = nil
        
        LinkPreviewDetectorHelper.setTest_debug_linkPreviewDetector(nil)
        
        super.tearDown()
    }
    
    func assertMessageContainsLinkPreview(_ message: ZMClientMessage, linkPreviewURL: MockLinkPreviewDetector.LinkPreviewURL, file: StaticString = #file, line: UInt = #line) {
        if let linkPreview = message.genericMessage?.linkPreviews.first {
            let expectedLinkPreview = mockLinkPreviewDetector.linkPreview(linkPreviewURL).protocolBuffer
            
            switch linkPreviewURL {
            case .articleWithPicture, .tweetWithPicture:
                XCTAssertTrue(linkPreview.image.hasUploaded() && linkPreview.article.image.hasUploaded(), "Link preview with image didn't contain uploaded asset", file: file, line: line)
                
                // We don't compare the whole proto buffer since the mock one won't have the uploaded image
                XCTAssertEqual(linkPreview.urlOffset, expectedLinkPreview.urlOffset)
                XCTAssertEqual(linkPreview.title, expectedLinkPreview.title)
                XCTAssertEqual(linkPreview.summary, expectedLinkPreview.summary)
            default:
                XCTAssertEqual(linkPreview, expectedLinkPreview, file: file, line: line)
                break
            }
        } else {
            XCTFail("Message didn't contain a link preview", file: file, line: line)
        }
    }
    
    func testThatItInsertsCorrectLinkPreviewMessage_ArticleWithoutImage() {
        // given
        XCTAssertTrue(login())
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        // when
        userSession?.performChanges {
            conversation?.append(text: MockLinkPreviewDetector.LinkPreviewURL.article.rawValue)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let message = conversation?.lastMessage as! ZMClientMessage
        assertMessageContainsLinkPreview(message, linkPreviewURL: .article)
    }
    
    func testThatItInsertCorrectLinkPreviewMessage_ArticleWithoutImage_ForEphemeral() {
        // given
        XCTAssertTrue(login())
        let conversation = self.conversation(for: selfToUser1Conversation)
        conversation?.messageDestructionTimeout = .local(10)
        
        // when
        userSession?.performChanges {
            conversation?.append(text: MockLinkPreviewDetector.LinkPreviewURL.article.rawValue)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let message = conversation?.lastMessage as! ZMClientMessage
        assertMessageContainsLinkPreview(message, linkPreviewURL: .article)
    }
    
    func testThatItInsertsCorrectLinkPreviewMessage_ArticleWithImage() {
        // given
        XCTAssertTrue(login())
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        // when
        userSession?.performChanges {
            conversation?.append(text: MockLinkPreviewDetector.LinkPreviewURL.articleWithPicture.rawValue)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let message = conversation?.lastMessage as! ZMClientMessage
        assertMessageContainsLinkPreview(message, linkPreviewURL: .articleWithPicture)
    }
    
    
    func testThatItInsertsCorrectLinkPreviewMessage_TwitterStatus() {
        // given
        XCTAssertTrue(login())
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        // when
        userSession?.performChanges {
            conversation?.append(text: MockLinkPreviewDetector.LinkPreviewURL.tweet.rawValue)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let message = conversation?.lastMessage as! ZMClientMessage
        assertMessageContainsLinkPreview(message, linkPreviewURL: .tweet)
    }
    
    func testThatItInsertsCorrectLinkPreviewMessage_TwitterStatusWithImage() {
        // given
        XCTAssertTrue(login())
        let conversation = self.conversation(for: selfToUser1Conversation)
        
        // when
        userSession?.performChanges {
            conversation?.append(text: MockLinkPreviewDetector.LinkPreviewURL.tweetWithPicture.rawValue)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let message = conversation?.lastMessage as! ZMClientMessage
        assertMessageContainsLinkPreview(message, linkPreviewURL: .tweetWithPicture)
    }
    
    func testThatItUpdatesMessageWhenReceivingLinkPreviewUpdate() {
        // given
        XCTAssertTrue(login())
        
        let mockConversation = selfToUser1Conversation!
        let conversation = self.conversation(for: mockConversation)
        
        establishSession(with: user1)
        let selfClient = selfUser.clients.anyObject() as! MockUserClient
        let senderClient = user1.clients.anyObject() as! MockUserClient
        
        let nonce = UUID.create()
        let messageText = MockLinkPreviewDetector.LinkPreviewURL.article.rawValue
        let messageWithoutLinkPreview = ZMGenericMessage.message(content: ZMText.text(with: messageText), nonce: nonce)
        
        // when - receiving initial message without the link preview
        mockTransportSession.performRemoteChanges { _ in
            mockConversation.encryptAndInsertData(from: senderClient, to: selfClient, data: messageWithoutLinkPreview.data())
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        
        let linkPreview = mockLinkPreviewDetector.linkPreview(.article).protocolBuffer
        let messageWithLinkPreview = ZMGenericMessage.message(content: ZMText.text(with: messageText, linkPreviews: [linkPreview]), nonce: nonce)
        
        // when - receiving update message with the link preview
        mockTransportSession.performRemoteChanges { _ in
            mockConversation.encryptAndInsertData(from: senderClient, to: selfClient, data: messageWithLinkPreview.data())
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let message = conversation?.lastMessage as! ZMClientMessage
        assertMessageContainsLinkPreview(message, linkPreviewURL: .article)
    }

}
