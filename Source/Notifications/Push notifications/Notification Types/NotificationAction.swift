//

import Foundation
import UserNotifications

/// An object that describes the configuration for text input actions.
struct NotificationActionTextInputMode {

    /// The format string for the localized title of the action/send button.
    let buttonTitleFormat: String

    /// The format string for the localized placeholder text of the input field.
    let placeholderFormat: String

}

/**
 * An object that describes a notification that can be performed by the user for a notification.
 */

protocol NotificationAction {

    /// The identifier of the action.
    var identifier: String { get }

    /// The format for the localized action string.
    var titleFormat: String { get }

    /// Whether the action deletes content when executed.
    var isDestructive: Bool { get }

    /// Whether the action opens the app when executed.
    var opensApplication: Bool { get }

    /// Whether the action requires the device to be unlocked before being executed.
    var requiresAuthentication: Bool { get }

    /// The optional configuration for text input, if the action supports it.
    var textInputMode: NotificationActionTextInputMode? { get }

}

extension NotificationAction where Self: RawRepresentable, Self.RawValue == String {
    var identifier: String {
        return rawValue
    }
}

extension NotificationAction {

    /// The representation of the action that can be used with `UserNotifications` API.
    var userAction: UNNotificationAction {
        if let textInputMode = self.textInputMode {
            return UNTextInputNotificationAction(
                identifier: identifier,
                title: titleFormat.pushActionString,
                options: options,
                textInputButtonTitle: textInputMode.buttonTitleFormat.pushActionString,
                textInputPlaceholder: textInputMode.placeholderFormat.pushActionString
            )
        } else {
            return UNNotificationAction(
                identifier: identifier,
                title: titleFormat.pushActionString,
                options: options)
        }
    }

    private var options: UNNotificationActionOptions {
        var rawOptions = UNNotificationActionOptions()

        if isDestructive {
            rawOptions.insert(.destructive)
        }

        if opensApplication {
            rawOptions.insert(.foreground)
        }

        if requiresAuthentication {
            rawOptions.insert(.authenticationRequired)
        }

        return rawOptions
    }

}

// MARK: - Concrete Actions

enum ConversationNotificationAction: String, NotificationAction {
    case open = "conversationOpenAction"
    case reply = "conversationDirectReplyAction"
    case mute = "conversationMuteAction"
    case like = "messageLikeAction"
    case connect = "acceptConnectAction"

    var titleFormat: String {
        switch self {
        case .open: return "message.open"
        case .reply: return "message.reply"
        case .mute: return "conversation.mute"
        case .like: return "message.like"
        case .connect: return "connection.accept"
        }
    }

    var isDestructive: Bool {
        return false
    }

    var opensApplication: Bool {
        switch self {
        case .open:
            return true
        default:
            return false
        }
    }

    var requiresAuthentication: Bool {
        return false
    }

    var textInputMode: NotificationActionTextInputMode? {
        switch self {
        case .reply:
            return NotificationActionTextInputMode(
                buttonTitleFormat: "message.reply.button.title",
                placeholderFormat: "message.reply.placeholder"
            )

        default:
            return nil
        }
    }
}

enum CallNotificationAction: String, NotificationAction {
    case ignore = "ignoreCallAction"
    case accept = "acceptCallAction"
    case callBack = "callbackCallAction"
    case message = "conversationDirectReplyAction"

    var titleFormat: String {
        switch self {
        case .ignore: return "call.ignore"
        case .accept: return "call.accept"
        case .callBack: return "call.callback"
        case .message: return "call.message"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .ignore:
            return true
        default:
            return false
        }
    }

    var opensApplication: Bool {
        switch self {
        case .accept, .callBack:
            return true
        default:
            return false
        }
    }

    var requiresAuthentication: Bool {
        return false
    }

    var textInputMode: NotificationActionTextInputMode? {
        switch self {
        case .message:
            return NotificationActionTextInputMode(
                buttonTitleFormat: "message.reply.button.title",
                placeholderFormat: "message.reply.placeholder"
            )

        default:
            return nil
        }
    }
}
