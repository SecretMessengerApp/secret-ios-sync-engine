//

import Foundation

@objc extension ZMUserSession {
    
    // MARK: - Foreground Actions
    
    public func acceptConnectionRequest(with userInfo: NotificationUserInfo, completionHandler: @escaping () -> Void) {
        
        guard let senderID = userInfo.senderID,
              let sender = ZMUser.fetch(withRemoteIdentifier: senderID, in: managedObjectContext),
              let conversation = sender.connection?.conversation
        else { return }
        
        sender.accept()
        managedObjectContext.saveOrRollback()
        showConversation(conversation)
        completionHandler()
    }
    
    public func acceptCall(with userInfo: NotificationUserInfo, completionHandler: @escaping () -> Void) {
        
        guard let conversation = userInfo.conversation(in: managedObjectContext) else { return }
        
        defer {
            showConversation(conversation)
            completionHandler()
        }
        
        guard let callState = conversation.voiceChannel?.state else { return }
        
        if case let .incoming(video: video, shouldRing: _, degraded: _) = callState, callCenter?.activeCallConversations(in: self).count == 0 {
            _ = conversation.voiceChannel?.join(video: video, userSession: self)
        }
    }
    
    func showContent(for userInfo: NotificationUserInfo) {
        
        guard let conversation = userInfo.conversation(in: managedObjectContext) else {
            sessionManager?.showConversationList(in: self)
            return
        }
        
        guard let message = userInfo.message(in: conversation, managedObjectContext: managedObjectContext) as? ZMClientMessage else {
            return showConversation(conversation)
        }
        
        if let textMessageData = message.textMessageData, textMessageData.isMentioningSelf {
            showConversation(conversation, at: conversation.firstUnreadMessageMentioningSelf)
        } else {
            showConversation(conversation, at: message)
        }
    }
        
    fileprivate func showConversation(_ conversation: ZMConversation, at message : ZMConversationMessage? = nil) {
        sessionManager?.showConversation(conversation, at: message, in: self)
    }
    
    // MARK: - Background Actions
    
    public func ignoreCall(with userInfo: NotificationUserInfo, completionHandler: @escaping () -> Void) {
        guard let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: "IgnoreCall Action Handler") else {
            return
        }

        let conversation = userInfo.conversation(in: managedObjectContext)
        
        managedObjectContext.perform { 
            conversation?.voiceChannel?.leave(userSession: self, completion: nil)
            BackgroundActivityFactory.shared.endBackgroundActivity(activity)
            completionHandler()
        }
    }
    
    public func muteConversation(with userInfo: NotificationUserInfo, completionHandler: @escaping () -> Void) {
        guard let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: "Mute Conversation Action Handler") else {
            return
        }

        let conversation = userInfo.conversation(in: managedObjectContext)

        managedObjectContext.perform {
            conversation?.mutedMessageTypes = .regular
            self.managedObjectContext.saveOrRollback()
            BackgroundActivityFactory.shared.endBackgroundActivity(activity)
            completionHandler()
        }
    }
    
    public func reply(with userInfo: NotificationUserInfo, message: String, completionHandler: @escaping () -> Void) {
        guard
            !message.isEmpty,
            let conversation = userInfo.conversation(in: managedObjectContext)
            else { return completionHandler() }

        guard let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: "DirectReply Action Handler") else {
            return
        }

        operationStatus.startBackgroundTask { [weak self] (result) in
            guard let `self` = self else { return }

            self.messageReplyObserver = nil
            self.syncManagedObjectContext.performGroupedBlock {
            
                let conversationOnSyncContext = userInfo.conversation(in: self.syncManagedObjectContext)
                if result == .failed {
                    Logging.push.safePublic("failed to reply via push notification action")
                    self.localNotificationDispatcher.didFailToSendMessage(in: conversationOnSyncContext!)
                } else {
                    self.syncManagedObjectContext.analytics?.tagActionOnPushNotification(conversation: conversationOnSyncContext, action: .text)
                }
                BackgroundActivityFactory.shared.endBackgroundActivity(activity)
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
        
        enqueueChanges {
            guard let message = conversation.append(text: message) else { return /* failure */ }
            self.appendReadReceiptIfNeeded(with: userInfo, in: conversation)
            self.messageReplyObserver = ManagedObjectContextChangeObserver(context: self.managedObjectContext, callback: { [weak self] in
                self?.updateBackgroundTask(with: message)
            })
        }
    }
    
    private func appendReadReceiptIfNeeded(with userInfo: NotificationUserInfo, in conversation: ZMConversation) {
        if let originalMessage = userInfo.message(in: conversation, managedObjectContext: self.managedObjectContext) as? ZMClientMessage,
            originalMessage.needsReadConfirmation {
            let confirmation = ZMGenericMessage.message(content: ZMConfirmation.confirm(messageId: originalMessage.nonce!, type: .READ))
            conversation.appendClientMessage(with: confirmation)
        }
    }
    
    public func handleTrackingOnCallNotification(with userInfo: NotificationUserInfo) {
        
        guard
            let conversation = userInfo.conversation(in: managedObjectContext),
            let callState = conversation.voiceChannel?.state,
            case .incoming(video: _, shouldRing: _, degraded: _) = callState,
            let callCenter = self.callCenter,
            callCenter.activeCallConversations(in: self).count == 0
            else { return }
                
        let type : ConversationMediaAction = callCenter.isVideoCall(conversationId: conversation.remoteIdentifier!) ? .videoCall : .audioCall

        self.syncManagedObjectContext.performGroupedBlock { [weak self] in
            guard
                let `self` = self,
                let conversationInSyncContext = userInfo.conversation(in: self.syncManagedObjectContext)
                else { return }
            
            self.syncManagedObjectContext.analytics?.tagActionOnPushNotification(conversation: conversationInSyncContext, action: type)
        }
    }
    
    public func likeMessage(with userInfo: NotificationUserInfo, completionHandler: @escaping () -> Void) {
        guard
            let conversation = userInfo.conversation(in: managedObjectContext),
            let message = userInfo.message(in: conversation, managedObjectContext: managedObjectContext)
            else { return completionHandler() }

        guard let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: "Like Message Activity") else {
            return
        }

        operationStatus.startBackgroundTask { [weak self] (result) in
            guard let `self` =  self else { return }
        
            self.likeMesssageObserver = nil
            if result == .failed {
                Logging.push.safePublic("failed to like message via push notification action")
            }
            BackgroundActivityFactory.shared.endBackgroundActivity(activity)
            completionHandler()
        }
            
        enqueueChanges {
            guard let reaction = ZMMessage.addReaction(.like, toMessage: message) else { return }
            self.appendReadReceiptIfNeeded(with: userInfo, in: conversation)
            self.likeMesssageObserver = ManagedObjectContextChangeObserver(context: self.managedObjectContext, callback: { [weak self] in
                self?.updateBackgroundTask(with: reaction)
            })
        }
    }
    
    func updateBackgroundTask(with message : ZMConversationMessage) {
        if message.isSent {
            operationStatus.finishBackgroundTask(withTaskResult: .finished)
        } else if message.deliveryState == .failedToSend {
            operationStatus.finishBackgroundTask(withTaskResult: .failed)
        }
    }
 
}
        
public extension ZMUserSession {
    public func markAllConversationsAsRead() {
        let allConversations = managedObjectContext.fetchOrAssert(request: NSFetchRequest<ZMConversation>(entityName: ZMConversation.entityName()))
        allConversations.forEach({ $0.markAsRead() })
    }
}
