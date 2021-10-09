//

import Foundation
import WireSyncEngine

/// A mock of Application that records the calls
@objcMembers public final class ApplicationMock : NSObject {
    
    public var applicationState: UIApplication.State = .active
    
    /// Records calls to `registerForRemoteNotification`
    public var registerForRemoteNotificationCount : Int = 0
    
    /// The current badge icon number
    public var applicationIconBadgeNumber: Int = 0
    
    /// Records calls to `setMinimumBackgroundFetchInterval`
    public var minimumBackgroundFetchInverval : TimeInterval = UIApplication.backgroundFetchIntervalNever
    
    /// Callback invoked when `registerUserNotificationSettings` is invoked
    public var registerForRemoteNotificationsCallback : () -> Void = { }
}

// MARK: - Application protocol
extension ApplicationMock : ZMApplication {
    
    public func registerForRemoteNotifications() {
        self.registerForRemoteNotificationCount += 1
        self.registerForRemoteNotificationsCallback()
    }
    
    public func setMinimumBackgroundFetchInterval(_ minimumBackgroundFetchInterval: TimeInterval) {
        self.minimumBackgroundFetchInverval = minimumBackgroundFetchInterval
    }
    
    public func executeWhenFileSystemIsAccessible(_ block: @escaping () -> Void) {
        block()
    }
}

// MARK: - Observers
extension ApplicationMock {
    
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
}

// MARK: - Simulate application state change
extension ApplicationMock {
    
    @objc public func simulateApplicationDidBecomeActive() {
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc public func simulateApplicationWillResignActive() {
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc public func simulateApplicationWillEnterForeground() {
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc public func simulateApplicationDidEnterBackground() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc public func simulateApplicationWillTerminate() {
        NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
    }
    
    var isInBackground : Bool {
        return self.applicationState == .background
    }
    
    @objc func setBackground() {
        self.applicationState = .background
    }
    
    var isInactive : Bool {
        return self.applicationState == .inactive
    }
    
    @objc func setInactive() {
        self.applicationState = .inactive
    }
    
    var isActive : Bool {
        return self.applicationState == .active
    }
    
    @objc func setActive() {
        self.applicationState = .active
    }

}
