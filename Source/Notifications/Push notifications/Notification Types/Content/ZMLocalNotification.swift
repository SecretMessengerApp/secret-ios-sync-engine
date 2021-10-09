//

import UIKit
import UserNotifications
import WireSystem
import WireUtilities
import WireTransport
import WireDataModel


/// Defines the various types of local notifications, some of which
/// have associated subtypes.
///
public enum LocalNotificationType {
    case event(LocalNotificationEventType)
    case calling(CallState)
    case message(LocalNotificationContentType)
    case failedMessage
    case availabilityBehaviourChangeAlert(Availability)
}

/// A notification builder provides the main components used to configure
/// a local notification. 
///
protocol NotificationBuilder {
    var notificationType : LocalNotificationType { get }
    func shouldCreateNotification() -> Bool
    func titleText() -> String?
    func bodyText() -> String
    func userInfo() -> NotificationUserInfo?
}


/// This class encapsulates all the data necessary to produce a local
/// notification. It configures and formats the textual content for
/// various notification types (message, calling, etc.) and includes
/// information regarding the conversation, sender, and team name.
///
public class ZMLocalNotification: NSObject {
    
    /// The unique identifier for this notification. Use it to later update
    /// or remove pending or scheduled notification requests.
    public let id: UUID
    
    public let type: LocalNotificationType
    public var title: String?
    public var body: String
    public var category: String
    public var sound: NotificationSound
    public var userInfo: NotificationUserInfo?
    
    deinit {
        print("ZMLocalNotification deinit")
    }

    init?(conversation: ZMConversation?, builder: NotificationBuilder) {
        guard builder.shouldCreateNotification() else { return nil }
        self.type = builder.notificationType
        self.title = builder.titleText()
        self.body = builder.bodyText()
        self.category = builder.notificationType.category(hasTeam: builder.userInfo()?.teamName != nil)
        self.sound = builder.notificationType.sound
        self.userInfo = builder.userInfo()
        self.id = userInfo?.messageNonce ?? UUID()
        super.init()
        
        self.userInfo?.requestID = id
    }

    /// Returns a configured concrete `UNNotificationContent` object.
    public lazy var content: UNNotificationContent = {
        let content = UNMutableNotificationContent()
        content.body = self.body
        content.categoryIdentifier = self.category
        content.sound = UNNotificationSound(named: convertToUNNotificationSoundName(sound.name))

        if let title = self.title {
            content.title = title
        }

        if let userInfo = self.userInfo {
            content.userInfo = userInfo.storage
        }

        // only group non ephemeral messages
        if let conversationID = self.conversationID {
            switch self.type {
            case .message(.ephemeral): break
            default: content.threadIdentifier = conversationID.transportString()
            }            
        }

        return content
    }()
    
    /// Returns a configured concrete `UNNotificationRequest`.
    public lazy var request: UNNotificationRequest = {
        return UNNotificationRequest(identifier: id.uuidString, content: content, trigger: nil)
    }()

}

// MARK: - Properties

extension ZMLocalNotification {

    public var selfUserID: UUID? { return userInfo?.selfUserID }
    public var senderID: UUID? { return userInfo?.senderID }
    public var messageNonce: UUID? { return userInfo?.messageNonce }
    public var conversationID: UUID? { return userInfo?.conversationID }

    /// Returns true if it is a calling notification, else false.
    public var isCallingNotification: Bool {
        switch type {
        case .calling: return true
        default: return false
        }
    }
    
    /// Returns true if it is a ephemeral notification, else false.
    public var isEphemeral: Bool {
        guard case .message(.ephemeral) = type else { return false }
        return true
    }

}

// MARK: - Lookup

extension ZMLocalNotification {

    public func conversation(in moc: NSManagedObjectContext) -> ZMConversation? {
        return userInfo?.conversation(in: moc)
    }
    
    public func sender(in moc: NSManagedObjectContext) -> ZMUser? {
        return userInfo?.sender(in: moc)
    }
}

// Helper function inserted by Swift 4.2 migrator.
public func convertToUNNotificationSoundName(_ input: String) -> UNNotificationSoundName {
	return UNNotificationSoundName(rawValue: input)
}
