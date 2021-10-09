//

import Foundation

class ZMConversationVoiceChannelTests : MessagingTest {
    
    private var oneToOneconversation : ZMConversation!
    private var groupConversation : ZMConversation!

    override func setUp() {
        super.setUp()
        
        oneToOneconversation = ZMConversation.insertNewObject(in: self.syncMOC)
        oneToOneconversation?.remoteIdentifier = UUID.create()
        oneToOneconversation.conversationType = .oneOnOne
        
        groupConversation = ZMConversation.insertNewObject(in: self.syncMOC)
        groupConversation?.remoteIdentifier = UUID.create()
        groupConversation.conversationType = .group
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    func testThatItReturnsAVoiceChannelForAOneOnOneConversations() {
        // when
        let voiceChannel = oneToOneconversation.voiceChannel
        
        // then
        XCTAssertNotNil(voiceChannel)
        XCTAssertEqual(voiceChannel?.conversation, oneToOneconversation)
    }
    
    func testThatItReturnsAVoiceChannelForAGroupConversation() {
        // when
        let voiceChannel = groupConversation.voiceChannel
        
        // then
        XCTAssertNotNil(voiceChannel)
        XCTAssertEqual(voiceChannel?.conversation, groupConversation)
    }
    
    func testThatItAlwaysReturnsTheSameVoiceChannelForAOneOnOneConversations() {
        // when
        let voiceChannel = oneToOneconversation.voiceChannel
        
        // then
        XCTAssertTrue(oneToOneconversation.voiceChannel === voiceChannel)
    }
    
}
