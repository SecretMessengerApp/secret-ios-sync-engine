
import Foundation
import WireRequestStrategy

extension ZMLocalNotification {
    
    // for each supported event type, use the corresponding notification builder.
    //
    public convenience init?(noticationEvent event: ZMUpdateEvent, conversation: ZMConversation?, managedObjectContext moc: NSManagedObjectContext) {
        var builder: NotificationBuilder?
        
        switch event.type {
        case .conversationOtrMessageAdd,
             .conversationClientMessageAdd,
             .conversationOtrAssetAdd,
             .conversationServiceMessageAdd,
             .conversationJsonMessageAdd,
             .conversationBgpMessageAdd:
            let message = ZMOTRMessage.createOrUpdate(from: event, in: moc, prefetchResult: nil)
            guard let msg = message else {return nil}
            builder = NSEMessageNotificationBuilder(message: msg)
            msg.markAsSent()
            
        case .conversationAppMessageAdd,
            .conversationMemberLeave,
            .conversationMemberJoin:
            guard let systemMessage = ZMSystemMessage.createOrUpdate(from: event, in: moc, prefetchResult: nil) else {
                return nil
            }
            
            if let sysMessage = systemMessage as? ZMSystemMessage,  (sysMessage.systemMessageType == .participantsAdded ||
                sysMessage.systemMessageType == .participantsRemoved) {
                let selfUser = ZMUser.selfUser(in: moc)
                
                if sysMessage.sender?.remoteIdentifier.transportString() == selfUser.remoteIdentifier.transportString() {
                    return nil
                }
                
                if !sysMessage.userIDs.contains(selfUser.remoteIdentifier.transportString()) {
                    return nil
                }
            }
            builder = NSEMessageNotificationBuilder(message: systemMessage)
            
        case .conversationCreate:
            builder = ConversationCreateEventNotificationBuilder(event: event, conversation: conversation, managedObjectContext: moc)
            
        case .conversationDelete:
            builder = ConversationDeleteEventNotificationBuilder(event: event, conversation: conversation, managedObjectContext: moc)
            
        case .userConnection:
            builder = UserConnectionEventNotificationBuilder(event: event, conversation: conversation, managedObjectContext: moc)
            
        case .userContactJoin:
            builder = NewUserEventNotificationBuilder(event: event, conversation: conversation, managedObjectContext: moc)
            
        default:
            builder = nil
        }
        
        moc.saveOrRollback()
        
        if let builder = builder {
            self.init(conversation: conversation, builder: builder)
        } else {
            return nil
        }
    }
    
}
