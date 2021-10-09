//

import Foundation

extension IntegrationTest {
    
    func remotelyInsert(text: String, from senderClient: MockUserClient, into conversation: MockConversation) {
        remotelyInsert(content: ZMText.text(with: text), from: senderClient, into: conversation)
    }
    
    func remotelyInsert(content: MessageContentType, from senderClient: MockUserClient, into conversation: MockConversation) {
        remotelyInsert(genericMessage: ZMGenericMessage.message(content: content), from: senderClient, into: conversation)
    }
    
    func remotelyInsert(genericMessage: ZMGenericMessage, from senderClient: MockUserClient, into conversation: MockConversation) {
        mockTransportSession.performRemoteChanges { _ in
            conversation.encryptAndInsertData(from:senderClient, to: self.selfUser.clients.anyObject() as! MockUserClient, data: genericMessage.data())
        }
    }
    
}
