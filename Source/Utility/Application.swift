//

import Foundation
import WireTransport
import UIKit

/// An abstraction of the application (UIApplication, NSApplication)
@objc public protocol ZMApplication : NSObjectProtocol {
    
    /// The current application state
    var applicationState : UIApplication.State { get }
    
    /// Badge count
    var applicationIconBadgeNumber : Int { get set }
    
    /// To determine if notification settings should be registered
//    @objc optional var shouldRegisterUserNotificationSettings : Bool { get }
    
    /// Register for remote notification
    func registerForRemoteNotifications()
    
    /// Register for change in application state: didBecomeActive
    @objc func registerObserverForDidBecomeActive(_ object: NSObject, selector: Selector)

    /// Register for change in application state: willResignActive
    @objc func registerObserverForWillResignActive(_ object: NSObject, selector: Selector)
    
    /// Register for change in application state: didBecomeActive
    @objc func registerObserverForWillEnterForeground(_ object: NSObject, selector: Selector)
    
    /// Register for change in application state: willResignActive
    @objc func registerObserverForDidEnterBackground(_ object: NSObject, selector: Selector)
    
    /// Register for application will terminate
    @objc func registerObserverForApplicationWillTerminate(_ object: NSObject, selector: Selector)
    
    /// Unregister for change in application state
    @objc func unregisterObserverForStateChange(_ object: NSObject)
    
    /// Sets minimum interval for background fetch
    @objc func setMinimumBackgroundFetchInterval(_ minimumBackgroundFetchInterval: TimeInterval)
    
    /// Executes the given block when the file system is unlocked
    @objc func executeWhenFileSystemIsAccessible(_ block: @escaping () -> Void)
}


extension UIApplication : ZMApplication {
    
    @objc public func registerObserverForDidBecomeActive(_ object: NSObject, selector: Selector) {
        NotificationCenter.default.addObserver(object, selector: selector, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc public func registerObserverForWillResignActive(_ object: NSObject, selector: Selector) {
        NotificationCenter.default.addObserver(object, selector: selector, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc public func registerObserverForWillEnterForeground(_ object: NSObject, selector: Selector) {
        NotificationCenter.default.addObserver(object, selector: selector, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc public func registerObserverForDidEnterBackground(_ object: NSObject, selector: Selector) {
        NotificationCenter.default.addObserver(object, selector: selector, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc public func registerObserverForApplicationWillTerminate(_ object: NSObject, selector: Selector) {
        NotificationCenter.default.addObserver(object, selector: selector, name: UIApplication.willTerminateNotification, object: nil)
    }
    
    @objc public func unregisterObserverForStateChange(_ object: NSObject) {
        NotificationCenter.default.removeObserver(object, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(object, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(object, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(object, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(object, name: UIApplication.willTerminateNotification, object: nil)
    }
    
    @objc public func executeWhenFileSystemIsAccessible(_ block: @escaping () -> Void) {
        if isProtectedDataAvailable || ZMPersistentCookieStorage.hasAccessibleAuthenticationCookieData() {
            block()
        } else {
            var token: Any? = nil
            token = NotificationCenter.default.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: nil) { _ in
                block()
                NotificationCenter.default.removeObserver(token!)
            }
        }
    }
}
