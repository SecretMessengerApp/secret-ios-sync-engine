//


import Foundation
import WireTransport
import UserNotifications

let PushChannelUserIDKey = "user"
let PushChannelDataKey = "data"
let PushChannelConvIDKey = "conv"
let PushChannelTypeKey = "type"
let PushChannelCallUserIDKey = "call_user_id"
let PushChannelCallUserNameKey = "call_user_name"
let PushChannelCallConversationIDKey = "call_conv_id"
let PushChannelVideoKey = "video"
let PushChannelCallTypeKey = "call_type"

extension Dictionary {
    
    internal func accountId() -> UUID? {
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
            Logging.push.safePublic("No data dictionary in notification userInfo payload");
            return nil
        }
    
        guard let userIdString = userInfoData[PushChannelUserIDKey] as? String else {
            return nil
        }
    
        return UUID(uuidString: userIdString)
    }
    

    func pushChannelType() -> String? {
        
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
            //            log.debug("No data dictionary in notification userInfo payload");
            return nil
        }
        
        guard let pushChannelType = userInfoData[PushChannelTypeKey] as? String else {
            //            log.debug("No Conv ID in notification userInfo payload")
            return nil
        }
        
        return pushChannelType
    }
    

    internal func hugeGroupConversationId() -> UUID? {
        
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
//            log.debug("No data dictionary in notification userInfo payload");
            return nil
        }
        
        guard let cid = userInfoData[PushChannelConvIDKey] as? String else {
//            log.debug("No Conv ID in notification userInfo payload")
            return nil
        }
        
        return UUID(uuidString: cid)
    }
    
    internal func stringIdentifier() -> String {
        if let data = self[PushChannelDataKey as! Key] as? [AnyHashable : Any],
            let innerData = data["data"] as? [AnyHashable : Any],
            let id = innerData["id"] {
            return "\(id)"
        } else {
            return self.description
        }
    }
    
   
    internal func hugeGroupConversationPayloadDictionary() -> [AnyHashable : Any]? {
        
        guard let apsData = self["aps" as! Key] as? [String: Any] else {
            return nil
        }
        
        guard let userInfoString = apsData["alert"] as? String else {
            return nil
        }
        guard let jsonOblect = userInfoString.data(using: .utf8),
            let userInfoData = try? JSONSerialization.jsonObject(with: jsonOblect, options: []) as? [AnyHashable : Any] else {
                return nil
        }
        
        return ["data": userInfoData]
    }
    

    internal func callUserId() -> String? {
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
            Logging.push.safePublic("No data dictionary in notification userInfo payload");
            return nil
        }
    
        guard let userIdString = userInfoData[PushChannelCallUserIDKey] as? String else {
            return nil
        }
    
        return userIdString
    }
    

    func userName() -> String? {
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
            Logging.push.safePublic("No data dictionary in notification userInfo payload");
            return nil
        }
    
        guard let userName = userInfoData[PushChannelCallUserNameKey] as? String else {
            return nil
        }
    
        return userName
    }
    

    internal func conversationId() -> String? {
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
            Logging.push.safePublic("No data dictionary in notification userInfo payload");
            return nil
        }
        
        guard let conversationId = userInfoData[PushChannelCallConversationIDKey] as? String else {
            return nil
        }
        
        return conversationId
    }
    
    func video() -> Bool? {
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
            Logging.push.safePublic("No data dictionary in notification userInfo payload");
            return nil
        }
    
        guard let video = userInfoData[PushChannelVideoKey] as? Bool else {
            return nil
        }
    
        return video
    }
    

    func callType() -> String? {
        guard let userInfoData = self[PushChannelDataKey as! Key] as? [String: Any] else {
            Logging.push.safePublic("No data dictionary in notification userInfo payload");
            return nil
        }
    
        guard let video = userInfoData[PushChannelCallTypeKey] as? String else {
            return nil
        }
    
        return video
    }
}

struct PushTokenMetadata {
    let isSandbox: Bool
    
    let appIdentifier: String
    var transportType: String {
        if isSandbox {
            return "APNS_VOIP_SANDBOX"
        }
        else {
            return "APNS_VOIP"
        }
    }
    
    static var current: PushTokenMetadata = {
        let appId = Bundle.main.bundleIdentifier ?? ""
        let buildType = BuildType.init(bundleID: appId)
        
        let isSandbox = ZMMobileProvisionParser().apsEnvironment == .sandbox
        let appIdentifier = buildType.certificateName
        
        let metadata = PushTokenMetadata(isSandbox: isSandbox, appIdentifier: appIdentifier)
        return metadata
    }()
}

struct ApnsPushTokenMetadata {
    let isSandbox: Bool
    let appIdentifier: String
    var transportType: String {
        if isSandbox {
            return "APNS_SANDBOX"
        }
        else {
            return "APNS"
        }
    }
    static var current: ApnsPushTokenMetadata = {
        let appId = Bundle.main.bundleIdentifier ?? ""
        let buildType = BuildType.init(bundleID: appId)
        
        let isSandbox = ZMMobileProvisionParser().apsEnvironment == .sandbox
        let appIdentifier = buildType.certificateName
        
        let metadata = ApnsPushTokenMetadata(isSandbox: isSandbox, appIdentifier: appIdentifier)
        return metadata
    }()
}

extension ZMUserSession {

    @objc public static let registerCurrentPushTokenNotificationName = Notification.Name(rawValue: "ZMUserSessionResetPushTokensNotification")

    @objc public func registerForRegisteringPushTokenNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(ZMUserSession.registerCurrentPushToken), name: ZMUserSession.registerCurrentPushTokenNotificationName, object: nil)
    }

    func setPushKitToken(_ data: Data) {
        let metadata = PushTokenMetadata.current

        let syncMOC = managedObjectContext.zm_sync!
        var isiOS13 = false
        if #available(iOS 13.3, *) {
            isiOS13 = true
        }
        syncMOC.performGroupedBlock {
            guard let selfClient = ZMUser.selfUser(in: syncMOC).selfClient() else { return }
            if selfClient.pushToken?.deviceToken != data ||
                selfClient.pushToken?.isUpdateiOS13 != isiOS13 ||
                selfClient.pushToken?.isiOS13Registered == false ||
                selfClient.pushToken?.isRegistered == false {
                selfClient.pushToken = PushToken(deviceToken: data,
                                                 appIdentifier: metadata.appIdentifier,
                                                 transportType: metadata.transportType,
                                                 isRegistered: false, randomCode: Int(arc4random() % 100))
                syncMOC.saveOrRollback()
            }
        }
    }
    
    func setApnsPushKitToken(_ token: String) {
        let metadata = ApnsPushTokenMetadata.current
        let syncMOC = managedObjectContext.zm_sync!
        syncMOC.performGroupedBlock {
            guard let selfClient = ZMUser.selfUser(in: syncMOC).selfClient() else { return }
            if selfClient.apnsPushToken?.deviceToken != token ||
                selfClient.apnsPushToken?.isRegistered == false  {
                selfClient.apnsPushToken = ApnsPushToken(deviceToken: token,
                                                 appIdentifier: metadata.appIdentifier,
                                                 transportType: metadata.transportType,
                                                 isRegistered: false, randomCode: Int(arc4random()) % 100)
                syncMOC.saveOrRollback()
            }
        }
    }

    func deletePushKitToken() {
        let syncMOC = managedObjectContext.zm_sync!
        syncMOC.performGroupedBlock {
            guard let selfClient = ZMUser.selfUser(in: syncMOC).selfClient() else { return }
            guard let pushToken = selfClient.pushToken else { return }
            selfClient.pushToken = pushToken.markToDelete()
            syncMOC.saveOrRollback()
        }
    }

    @objc public func registerCurrentPushToken() {
        managedObjectContext.performGroupedBlock {
            self.sessionManager.updatePushToken(for: self)
            self.sessionManager.updateApnsPushToken(for: self)
        }
    }

    /// Will compare the push token registered on backend with the local one
    /// and re-register it if they don't match
    public func validatePushToken() {
        let syncMOC = managedObjectContext.zm_sync!
        syncMOC.performGroupedBlock {
            guard let selfClient = ZMUser.selfUser(in: syncMOC).selfClient() else { return }
            guard let pushToken = selfClient.pushToken else {
                // If we don't have any push token, then try to register it again
                self.sessionManager.updatePushToken(for: self)
                return
            }
            selfClient.pushToken = pushToken.markToDownload()
            syncMOC.saveOrRollback()
        }
    }
}

extension ZMUserSession {
    
    @objc public func receivedPushNotification(with payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        Logging.network.debug("Received push notification with payload: \(payload)")
        
        guard let syncMoc = self.syncManagedObjectContext else {
            return
        }

        let accountID = self.storeProvider.userIdentifier;

        syncMoc.performGroupedBlock {
            let notAuthenticated = !self.isAuthenticated()
            
            if notAuthenticated {
                Logging.push.safePublic("Not displaying notification because app is not authenticated")
                completion()
                return
            }
            
            // once notification processing is finished, it's safe to update the badge
            let completionHandler = {
                completion()
                let unreadCount = Int(ZMConversation.unreadConversationCount(in: syncMoc))
                self.sessionManager?.updateAppIconBadge(accountID: accountID, unreadCount: unreadCount)
            }
            
            self.operationLoop.fetchEvents(fromPushChannelPayload: payload, completionHandler: completionHandler)
        }
    }
    
}

// MARK: - UNUserNotificationCenterDelegate

/*
 * Note: Although ZMUserSession conforms to UNUserNotificationCenterDelegate,
 * it should not actually be assigned as the delegate of UNUserNotificationCenter.
 * Instead, the delegate should be the SessionManager, whose repsonsibility it is
 * to forward the method calls to the appropriate user session.
 */
extension ZMUserSession: UNUserNotificationCenterDelegate {
    
    // Called by the SessionManager when a notification is received while the app
    // is in the foreground.
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        Logging.push.safePublic("Notification center wants to present in-app notification: \(notification)")
        let categoryIdentifier = notification.request.content.categoryIdentifier
        
        handleInAppNotification(with: notification.userInfo,
                                categoryIdentifier: categoryIdentifier,
                                completionHandler: completionHandler)
    }
    
    // Called by the SessionManager when the user engages a notification action.
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void)
    {
        Logging.push.safePublic("Did receive notification response: \(response)")
        let userText = (response as? UNTextInputNotificationResponse)?.userText
        let note = response.notification
        
        handleNotificationResponse(actionIdentifier: response.actionIdentifier,
                                   categoryIdentifier: note.request.content.categoryIdentifier,
                                   userInfo: note.userInfo,
                                   userText: userText,
                                   completionHandler: completionHandler)
    }
    
    // MARK: Abstractions
    
    /* The logic for handling notifications/actions is factored out of the
     * delegate methods because we cannot create `UNNotification` and
     * `UNNotificationResponse` objects in unit tests.
     */
    
    func handleInAppNotification(with userInfo: NotificationUserInfo,
                                 categoryIdentifier: String,
                                 completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        if categoryIdentifier == PushNotificationCategory.incomingCall.rawValue {
            self.handleTrackingOnCallNotification(with: userInfo)
        }
        
        // foreground notification responder exists on the UI context, so we
        // need to switch to that context
        self.managedObjectContext.perform {
            let responder = self.sessionManager.foregroundNotificationResponder
            let shouldPresent = responder?.shouldPresentNotification(with: userInfo)
            
            var options = UNNotificationPresentationOptions()
            if shouldPresent ?? true { options = [.alert, .sound] }
            
            completionHandler(options)
        }
    }
    
    @objc public func handleNotificationResponse(actionIdentifier: String,
                                    categoryIdentifier: String,
                                    userInfo: NotificationUserInfo,
                                    userText: String? = nil,
                                    completionHandler: @escaping () -> Void)
    {
        switch actionIdentifier {
        case CallNotificationAction.ignore.rawValue:
            ignoreCall(with: userInfo, completionHandler: completionHandler)
        case CallNotificationAction.accept.rawValue:
            acceptCall(with: userInfo, completionHandler: completionHandler)
        case ConversationNotificationAction.mute.rawValue:
            muteConversation(with: userInfo, completionHandler: completionHandler)
        case ConversationNotificationAction.like.rawValue:
            likeMessage(with: userInfo, completionHandler: completionHandler)
        case ConversationNotificationAction.reply.rawValue:
            if let textInput = userText {
                reply(with: userInfo, message: textInput, completionHandler: completionHandler)
            }
        case ConversationNotificationAction.connect.rawValue:
            acceptConnectionRequest(with: userInfo, completionHandler: completionHandler)
        default:
            showContent(for: userInfo)
            completionHandler()
            break
        }
    }
    
}

fileprivate extension UNNotificationContent {
    override open var description: String {
        return "<\(type(of:self)); threadIdentifier: \(self.threadIdentifier); content: redacted>"
    }
}
