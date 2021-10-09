//

import Foundation
import PushKit
import UserNotifications

protocol PushRegistry {
    
    var delegate: PKPushRegistryDelegate? { get set }
    var desiredPushTypes: Set<PKPushType>? { get set }
    
    func pushToken(for type: PKPushType) -> Data?
    
}

extension PKPushRegistry: PushRegistry {}

extension PKPushPayload {
    fileprivate var stringIdentifier: String {
        if let data = dictionaryPayload["data"] as? [AnyHashable : Any], let innerData = data["data"] as? [AnyHashable : Any], let id = innerData["id"] {
            return "\(id)"
        } else {
            return self.description
        }
    }
}


// MARK: - PKPushRegistryDelegate

extension SessionManager: PKPushRegistryDelegate {
    
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        
        Logging.push.safePublic("PushKit token was updated: \(pushCredentials)")
        
        // give new push token to all running sessions
        backgroundUserSessions.values.forEach({ userSession in
            userSession.setPushKitToken(pushCredentials.token)
        })
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        
        Logging.push.safePublic("PushKit token was invalidated")
        
        // delete push token from all running sessions
        backgroundUserSessions.values.forEach({ userSession in
            userSession.deletePushKitToken()
        })
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        self.pushRegistry(registry, didReceiveIncomingPushWith: payload, for: type, completion: {})
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        // We only care about voIP pushes, other types are not related to push notifications (watch complications and files)
        guard type == .voIP else { return completion() }
        
        Logging.push.safePublic("Received push payload: \(payload)")
        Logging.push.info("Received push payload: \(payload.dictionaryPayload)")
        // We were given some time to run, resume background task creation.
        BackgroundActivityFactory.shared.resume()
        
        
        
        if #available(iOS 13.3, *) {
           
            if let callType = payload.dictionaryPayload.callType(),
                let userId = payload.dictionaryPayload.accountId() {
                pushCallNotification(to: userId, payload: payload, completion: completion)
                
            } else {
                completion()
            }
        } else {
           
            if let hugeGroupConversationId = payload.dictionaryPayload.hugeGroupConversationId() {
                if let pushType = payload.dictionaryPayload.pushChannelType(),
                    pushType == "notice-sie" {
                    accountManager.accounts.forEach { account in
                        self.pushNotification(to: account.userIdentifier, payload: payload, completion: completion)
                    }
                } else {
                    pushNotificationToAccount(conversation: hugeGroupConversationId, needBeNoticedAccount: { [weak self] accountNeedBeNoticed in
                        self?.pushNotification(to: accountNeedBeNoticed.userIdentifier, payload: payload, completion: completion)
                    })
                }
            }
            
            else if
                let payloadDictionary = payload.dictionaryPayload.hugeGroupConversationPayloadDictionary(),
                let hugeGroupConversationId = payloadDictionary.hugeGroupConversationId() {
                
                if let pushType = payloadDictionary.pushChannelType(),
                    pushType == "notice-sie" {
                    accountManager.accounts.forEach { account in
                        self.pushSadboxNotification(to: account.userIdentifier, payloadDictionary: payloadDictionary, completion: completion)
                    }
                } else {
                    pushNotificationToAccount(conversation: hugeGroupConversationId, needBeNoticedAccount: { [weak self] accountNeedBeNoticed in
                        self?.pushSadboxNotification(to: accountNeedBeNoticed.userIdentifier, payloadDictionary: payloadDictionary, completion: completion)
                    })
                }
            } else {
                guard let userId = payload.dictionaryPayload.accountId() else { return }
                pushNotification(to: userId, payload: payload, completion: completion)
            }
        }
    }
 
    private func pushSadboxNotification(to userId: UUID, payloadDictionary: [AnyHashable : Any], completion: @escaping () -> Void) {

        notificationsTracker?.registerReceivedPush()

        guard let account = accountManager.account(with: userId),
            let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: payloadDictionary.stringIdentifier(), expirationHandler: { [weak self] in
                self?.notificationsTracker?.registerProcessingExpired()
            }) else {
                notificationsTracker?.registerProcessingAborted()
                return completion()
        }

        withSession(for: account) { userSession in
            Logging.push.safePublic("Forwarding sadbox push payload to user session with account \(account.userIdentifier)")

            userSession.receivedPushNotification(with: payloadDictionary) { [weak self] in
                Logging.push.safePublic("Processing sadbox push payload completed")
                self?.notificationsTracker?.registerNotificationProcessingCompleted()
                BackgroundActivityFactory.shared.endBackgroundActivity(activity)
                completion()
            }
        }
    }
    
    private func pushNotification(to userId: UUID, payload: PKPushPayload, completion: @escaping () -> Void) {
        
        notificationsTracker?.registerReceivedPush()
        
        guard let account = accountManager.account(with: userId),
            let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: "\(payload.stringIdentifier)", expirationHandler: { [weak self] in
                Logging.push.safePublic("Processing push payload expired: \(payload)")
                self?.notificationsTracker?.registerProcessingExpired()
            }) else {
                Logging.push.safePublic("Aborted processing of payload: \(payload)")
                notificationsTracker?.registerProcessingAborted()
                return completion()
        }
        
        withSession(for: account) { userSession in
            Logging.push.safePublic("Forwarding push payload to user session with account \(account.userIdentifier)")
            
            userSession.receivedPushNotification(with: payload.dictionaryPayload) { [weak self] in
                Logging.push.safePublic("Processing push payload completed")
                self?.notificationsTracker?.registerNotificationProcessingCompleted()
                BackgroundActivityFactory.shared.endBackgroundActivity(activity)
                completion()
            }
        }
    }
    
    private func pushCallNotification(to userUUID: UUID, payload: PKPushPayload, completion: @escaping () -> Void) {
        guard let userName = payload.dictionaryPayload.userName(),
            let callUserId = payload.dictionaryPayload.callUserId(),
            let conversationId = payload.dictionaryPayload.conversationId(),
            let video = payload.dictionaryPayload.video(),
            let callType = payload.dictionaryPayload.callType() else {
                return completion()
        }
        
        notificationsTracker?.registerReceivedPush()
        
        guard let account = accountManager.account(with: userUUID),
            let activity = BackgroundActivityFactory.shared.startBackgroundActivity(withName: "\(payload.stringIdentifier)", expirationHandler: { [weak self] in
                Logging.push.safePublic("Processing push payload expired: \(payload)")
                self?.notificationsTracker?.registerProcessingExpired()
            }) else {
                Logging.push.safePublic("Aborted processing of payload: \(payload)")
                notificationsTracker?.registerProcessingAborted()
                return completion()
        }
        
        
        withSession(for: account) { userSession in
            Logging.push.safePublic("Forwarding push payload to user session with account \(account.userIdentifier)")
            BackgroundActivityFactory.shared.endBackgroundActivity(activity)
            
            userSession.receivedPushNotification(with: payload.dictionaryPayload) { [weak self] in
                Logging.push.safePublic("Processing push payload completed")
                self?.notificationsTracker?.registerNotificationProcessingCompleted()
                BackgroundActivityFactory.shared.endBackgroundActivity(activity)
            }
        }
        if callType == "1" {
            callKitManager?.reportIncomingCallV2(from: callUserId, userName: userName, conversationId: conversationId, video: video)
        } else {
            callKitManager?.requestEndCallV2(in: conversationId)
        }
        completion()
    }
    
    private func pushNotificationToAccount(conversation cid: UUID, needBeNoticedAccount: @escaping (Account) -> Void) {
        accountManager.accounts.forEach { account in
            if HugeConversationSetting.muteHugeConversationInBackground(with: cid, userId: account.userIdentifier.transportString()) {
                return
            }
            
            withSession(for: account) { userSession in
                needBeNoticedAccount(account)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

@objc extension SessionManager: UNUserNotificationCenterDelegate {
    
    // Called by the OS when the app receieves a notification while in the
    // foreground.
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        // route to user session
        handleNotification(with: notification.userInfo) { userSession in
            userSession.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
        }
    }
    
    // Called when the user engages a notification action.
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void)
    {
        // Resume background task creation.
        BackgroundActivityFactory.shared.resume()
        // route to user session
        handleNotification(with: response.notification.userInfo) { userSession in
            userSession.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
        }
    }
    
    // MARK: Helpers
    
    @objc public func configureUserNotifications() {
//        guard application.shouldRegisterUserNotificationSettings ?? true else { return }
        notificationCenter.setNotificationCategories(PushNotificationCategory.allCategories)
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { _, _ in })
        notificationCenter.delegate = self
    }
    
    public func updatePushToken(for session: ZMUserSession) {
        session.managedObjectContext.performGroupedBlock {
            // Refresh the tokens if needed
            if let token = self.pushRegistry.pushToken(for: .voIP) {
                session.setPushKitToken(token)
            }
        }
    }
    
    public func updateApnsPushToken(for session: ZMUserSession) {
        session.managedObjectContext.performGroupedBlock {
            // Refresh the Apns tokens if needed
            let token = UserDefaults.standard.string(forKey: ApnsPushTokenStrategy.Keys.UserClientApnsPushTokenKey)
            if let t = token {
                session.setApnsPushKitToken(t)
            }
        }
    }
    
    
    func handleNotification(with userInfo: NotificationUserInfo, block: @escaping (ZMUserSession) -> Void) {
        guard
            let selfID = userInfo.selfUserID,
            let account = accountManager.account(with: selfID)
            else { return }
        
        self.withSession(for: account, perform: block)
    }
    
    fileprivate func activateAccount(for session: ZMUserSession, completion: @escaping () -> ()) {
        if session == activeUserSession {
            completion()
            return
        }
        
        var foundSession: Bool = false
        self.backgroundUserSessions.forEach { accountId, backgroundSession in
            if session == backgroundSession, let account = self.accountManager.account(with: accountId) {
                self.select(account) {
                    completion()
                }
                foundSession = true
                return
            }
        }
        
        if !foundSession {
            fatalError("User session \(session) is not present in backgroundSessions")
        }
    }
}

// MARK: - ShowContentDelegate

public protocol ShowContentDelegate: class {
    func showConversation(_ conversation: ZMConversation, at message: ZMConversationMessage?)
    func showConversationList()
    func showUserProfile(user: UserType)
    func showConnectionRequest(userId: UUID)
}


extension SessionManager {
    
    public func showConversation(_ conversation: ZMConversation,
                                 at message: ZMConversationMessage? = nil,
                                 in session: ZMUserSession) {
        activateAccount(for: session) {
            self.showContentDelegate?.showConversation(conversation, at: message)
        }
    }
    
    public func showConversationList(in session: ZMUserSession) {
        activateAccount(for: session) {
            self.showContentDelegate?.showConversationList()
        }
    }


    public func showUserProfile(user: UserType) {
        self.showContentDelegate?.showUserProfile(user: user)
    }

    public func showConnectionRequest(userId: UUID) {
        self.showContentDelegate?.showConnectionRequest(userId: userId)
    }

}
