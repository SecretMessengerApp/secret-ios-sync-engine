////

import Foundation
import WireSyncEngine

@objc class UserNotificationCenterMock: NSObject, UserNotificationCenter {
    
    weak var delegate: UNUserNotificationCenterDelegate?
    
    /// Identifiers of scheduled notification requests.
    @objc var scheduledRequests = [UNNotificationRequest]()

    /// Identifiers of removed notifications.
    @objc var removedNotifications = Set<String>()
    
    /// The registered notification categories for the app.
    @objc var registeredNotificationCategories = Set<UNNotificationCategory>()
    
    /// The requested authorization options for the app.
    @objc var requestedAuthorizationOptions: UNAuthorizationOptions = []
    
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        registeredNotificationCategories.formUnion(categories)
    }
    
    func requestAuthorization(options: UNAuthorizationOptions,
                              completionHandler: @escaping (Bool, Error?) -> Void)
    {
        requestedAuthorizationOptions.insert(options)
    }
    
    func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?) {
        scheduledRequests.append(request)
    }
    
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedNotifications.formUnion(identifiers)
    }
    
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedNotifications.formUnion(identifiers)
    }
    
    func removeAllNotifications(withIdentifiers identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
        removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
