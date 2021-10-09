////

import Foundation

extension UNNotificationResponse: SafeForLoggingStringConvertible {
    public var safeForLoggingDescription: String {
        return "action:\(actionIdentifier) notification: [\(notification.safeForLoggingDescription)]"
    }
}
