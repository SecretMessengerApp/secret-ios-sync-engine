//


// MARK: - Calling

extension ZMLocalNotification {
    
    convenience init?(callState: CallState, conversation: ZMConversation, caller: ZMUser) {
        guard let builder = CallNotificationBuilder(callState: callState, caller: caller, conversation: conversation) else { return nil }
        
        self.init(conversation: conversation, builder: builder)
    }
    
    private class CallNotificationBuilder: NotificationBuilder {
        
        let callState: CallState
        let caller: ZMUser
        let conversation: ZMConversation
        let managedObjectContext: NSManagedObjectContext
        
        var notificationType: LocalNotificationType {
            return LocalNotificationType.calling(callState)
        }
        
        let ignoredCallStates : [CallState] = [
            .established, .answered(degraded: false), .outgoing(degraded: false), .none, .unknown
        ]
        
        init?(callState: CallState, caller: ZMUser, conversation: ZMConversation) {
            guard let managedObjectContext = conversation.managedObjectContext, conversation.remoteIdentifier != nil else { return nil }
            
            self.callState = callState
            self.caller = caller
            self.conversation = conversation
            self.managedObjectContext = managedObjectContext
        }
        
        func shouldCreateNotification() -> Bool {
            guard conversation.mutedMessageTypesIncludingAvailability != .all else { return false }
                        
            switch callState {
            case .terminating(reason: .anweredElsewhere), .terminating(reason: .normal), .terminating(reason: .rejectedElsewhere):
                return false
            case .incoming(video: _, shouldRing: let shouldRing, degraded: _):
                return shouldRing
            case .terminating:
                return true
            default:
                return false
            }
        }
        
        func titleText() -> String? {
            return notificationType.titleText(selfUser: ZMUser.selfUser(in: managedObjectContext), conversation: conversation)
        }
        
        func bodyText() -> String {
            return notificationType.messageBodyText(sender: caller, conversation: conversation)
        }
                
        func userInfo() -> NotificationUserInfo? {
            let selfUser = ZMUser.selfUser(in: managedObjectContext)

            guard let selfUserID = selfUser.remoteIdentifier,
                  let senderID = caller.remoteIdentifier,
                  let conversationID = conversation.remoteIdentifier
                  else { return nil }
            
            let userInfo = NotificationUserInfo()
            userInfo.selfUserID = selfUserID
            userInfo.senderID = senderID
            userInfo.conversationID = conversationID
            userInfo.conversationName = conversation.meaningfulDisplayName
            userInfo.teamName = selfUser.team?.name

            return userInfo
        }
    }
}
