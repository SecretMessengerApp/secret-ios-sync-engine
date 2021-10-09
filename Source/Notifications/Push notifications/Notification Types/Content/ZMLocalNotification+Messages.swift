//


// MARK: - Message

extension ZMLocalNotification {
    
    convenience init?(message: ZMMessage) {
        guard message.conversation?.remoteIdentifier != nil, let builder = MessageNotificationBuilder(message: message) else { return nil }
        
        self.init(conversation: message.conversation, builder: builder)
    }
    
}

public class MessageNotificationBuilder: NotificationBuilder {
    
    let message: ZMMessage
    fileprivate let contentType: LocalNotificationContentType
    fileprivate let managedObjectContext : NSManagedObjectContext
    
    let sender: ZMUser
    let conversation: ZMConversation
    
    init?(message: ZMMessage) {
        guard let sender = message.sender,
              let conversation = message.conversation,
              let managedObjectContext = message.managedObjectContext,
              let contentType = LocalNotificationContentType.typeForMessage(message) else {
            
                Logging.push.safePublic("Not creating local notification for message with nonce = \(message.nonce) because context is unknown")
                return nil
        }
        
        self.sender = sender
        self.conversation = conversation
        self.message = message
        self.contentType = contentType
        self.managedObjectContext = managedObjectContext
    }
    
    deinit {
        print("MessageNotificationBuilder deinit")
    }
    
    var notificationType: LocalNotificationType {
        if LocalNotificationDispatcher.shouldHideNotificationContent(moc: managedObjectContext), !message.isEphemeral {
            return LocalNotificationType.message(.hidden)
        } else {
            return LocalNotificationType.message(contentType)
        }
    }
    
    func shouldCreateNotification() -> Bool {
        guard !message.isSilenced else {
            Logging.push.safePublic("Not creating local notification for message with nonce = \(message.nonce) because conversation is silenced")
            return false
        }

        if let timeStamp = message.serverTimestamp,
           let lastRead = conversation.lastReadServerTimeStamp,
           lastRead.compare(timeStamp) != .orderedAscending
        {
            return false
        }
        
        return true
    }
    
    func titleText() -> String? {
        return notificationType.titleText(selfUser: ZMUser.selfUser(in: managedObjectContext), conversation: conversation)
    }
    
    func bodyText() -> String {
        return notificationType.messageBodyText(sender: sender, conversation: conversation).trimmingCharacters(in: .whitespaces)
    }
    
    func userInfo() -> NotificationUserInfo? {
        guard let moc = message.managedObjectContext else { return nil }
        let selfUser = ZMUser.selfUser(in: moc)

        guard let selfUserID = ZMUser.selfUser(in: moc).remoteIdentifier,
            let senderID = sender.remoteIdentifier,
            let conversationID = conversation.remoteIdentifier,
            let eventTime = message.serverTimestamp
            else { return nil }
        
        let userInfo = NotificationUserInfo()
        userInfo.selfUserID = selfUserID
        userInfo.senderID = senderID
        userInfo.messageNonce = message.nonce
        userInfo.conversationID = conversationID
        userInfo.eventTime = eventTime
        userInfo.conversationName = conversation.meaningfulDisplayName
        userInfo.teamName = selfUser.team?.name

        return userInfo
    }
}


// MARK: - System Message

extension ZMLocalNotification {
    
    convenience init?(systemMessage: ZMSystemMessage) {
        guard systemMessage.conversation?.remoteIdentifier != nil, let builder = SystemMessageNotificationBuilder(message: systemMessage) else { return nil }
        
        self.init(conversation: systemMessage.conversation, builder: builder)
    }
    
    class SystemMessageNotificationBuilder : MessageNotificationBuilder {
        
        override var notificationType: LocalNotificationType {
            return LocalNotificationType.message(contentType)
        }
        
        override func shouldCreateNotification() -> Bool {
            guard let systemMessage = message as? ZMSystemMessage else { return false }
            
            // we don't want to create notifications when other people join or leave conversation
            let forSelf = systemMessage.users.count == 1 && systemMessage.users.first!.isSelfUser
            // serviceMessage
            if !forSelf && systemMessage.systemMessageType != .messageTimerUpdate && systemMessage.systemMessageType != .serviceMessage {
                return false
            }
                        
            return super.shouldCreateNotification()
        }
        
    }

}


// MARK: - Failed Messages

extension ZMLocalNotification {
    
    convenience init?(expiredMessage: ZMMessage) {
        guard let conversation = expiredMessage.conversation else { return nil }
        self.init(expiredMessageIn: conversation)
    }
    
    convenience init?(expiredMessageIn conversation: ZMConversation) {
        guard let builder = FailedMessageNotificationBuilder(conversation: conversation) else { return nil }
        
        self.init(conversation: conversation, builder: builder)
    }
    
    private class FailedMessageNotificationBuilder: NotificationBuilder {
        
        fileprivate let conversation: ZMConversation
        fileprivate let managedObjectContext: NSManagedObjectContext
        
        var notificationType: LocalNotificationType {
            return LocalNotificationType.failedMessage
        }
        
        init?(conversation: ZMConversation?) {
            guard let conversation = conversation, let managedObjectContext = conversation.managedObjectContext else { return nil }
        
            self.conversation = conversation
            self.managedObjectContext = managedObjectContext
        }
        
        func shouldCreateNotification() -> Bool {
            return true
        }
        
        func titleText() -> String? {
            return notificationType.titleText(selfUser: ZMUser.selfUser(in: managedObjectContext), conversation: conversation)
        }
        
        func bodyText() -> String {
            return notificationType.messageBodyText(sender: ZMUser.selfUser(in: managedObjectContext), conversation: conversation)
        }
        
        func userInfo() -> NotificationUserInfo? {
            let selfUser = ZMUser.selfUser(in: managedObjectContext)
            
            guard let selfUserID = selfUser.remoteIdentifier,
                  let conversationID = conversation.remoteIdentifier else { return nil }
            
            let userInfo = NotificationUserInfo()
            userInfo.selfUserID = selfUserID
            userInfo.conversationID = conversationID
            userInfo.conversationName = conversation.meaningfulDisplayName
            userInfo.teamName = selfUser.team?.name
            
            return userInfo
        }
    }
}
