//

import Foundation
import UserNotifications

/**
 * The categories of notifications supported by the app.
 */

enum PushNotificationCategory: String, CaseIterable {
    
    case incomingCall = "incomingCallCategory"
    case missedCall = "missedCallCategory"
    case conversation = "conversationCategory"
    case conversationWithMute = "conversationCategoryWithMute"
    case conversationWithLike = "conversationCategoryWithLike"
    case conversationWithLikeAndMute = "conversationCategoryWithLikeAndMute"
    case connect = "connectCategory"
    case alert = "alertCategory"

    /// All the supported categories.
    static var allCategories: Set<UNNotificationCategory> {
        let categories = PushNotificationCategory.allCases.map(\.userNotificationCategory)

        return Set(categories)
    }

    /// The actions for notifications of this category.
    var actions: [NotificationAction] {
        switch self {
        case .incomingCall:
            return [CallNotificationAction.ignore, CallNotificationAction.message]
        case .missedCall:
            return [CallNotificationAction.callBack, CallNotificationAction.message]
        case .conversation:
            return [ConversationNotificationAction.reply]
        case .conversationWithMute:
            return [ConversationNotificationAction.reply, ConversationNotificationAction.mute]
        case .conversationWithLike:
            return [ConversationNotificationAction.reply, ConversationNotificationAction.like]
        case .conversationWithLikeAndMute:
            return [ConversationNotificationAction.reply, ConversationNotificationAction.like, ConversationNotificationAction.mute]
        case .connect:
            return [ConversationNotificationAction.connect]
        case .alert:
            return []
        }
    }

    /// The representation of the category that can be used with `UserNotifications` API.
    var userNotificationCategory: UNNotificationCategory {
        let userActions = self.actions.map(\.userAction)
        return UNNotificationCategory(identifier: rawValue, actions: userActions, intentIdentifiers: [], options: [])
    }
    
}
