////

import Foundation

/**
 * An abstraction of the `UNUserNotificationCenter` object to facilitate
 * mocking for unit tests.
 */

public protocol UserNotificationCenter: class {
    
    /// The object that processes incoming notifications and actions.
    var delegate: UNUserNotificationCenterDelegate? { get set }

    /// Registers the notification types and the custom actions they support.
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    
    // Requests authorization to use notifications.
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void)
    
    /// Schedules the request to display a local notification.
    func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?)
    
    /// Unschedules the specified notification requests.
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    
    /// Removes the specified notification requests from Notification Center
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    
    /// Removes all pending requests and delivered notifications with the given identifiers.
    func removeAllNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenter {
    
    public func removeAllNotifications(withIdentifiers identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
        removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
