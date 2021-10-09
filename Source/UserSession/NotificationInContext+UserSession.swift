//


import WireDataModel

// MARK: - Initial sync
@objc public protocol ZMInitialSyncCompletionObserver: NSObjectProtocol
{
    func initialSyncCompleted()
}

private let initialSyncCompletionNotificationName = Notification.Name(rawValue: "ZMInitialSyncCompletedNotification")

extension ZMUserSession : NotificationContext { } // Mark ZMUserSession as valid notification context

extension ZMUserSession {
    
    @objc public static func notifyInitialSyncCompleted(context: NSManagedObjectContext) {
        NotificationInContext(name: initialSyncCompletionNotificationName, context: context.notificationContext).post()
    }
    
    @objc public func addInitialSyncCompletionObserver(_ observer: ZMInitialSyncCompletionObserver) -> Any {
        return ZMUserSession.addInitialSyncCompletionObserver(observer, context: managedObjectContext)
    }
    
    @objc public static func addInitialSyncCompletionObserver(_ observer: ZMInitialSyncCompletionObserver, context: NSManagedObjectContext) -> Any {
        return NotificationInContext.addObserver(name: initialSyncCompletionNotificationName, context: context.notificationContext) {
            [weak observer] _ in
            context.performGroupedBlock {
                observer?.initialSyncCompleted()
            }
        }
    }
    
    @objc public static func addInitialSyncCompletionObserver(_ observer: ZMInitialSyncCompletionObserver, userSession: ZMUserSession) -> Any {
        return self.addInitialSyncCompletionObserver(observer, context: userSession.managedObjectContext)
    }
}

// MARK: - Network Availability
@objcMembers public class ZMNetworkAvailabilityChangeNotification : NSObject {

    private static let name = Notification.Name(rawValue: "ZMNetworkAvailabilityChangeNotification")
    
    private static let stateKey = "networkState"
    
    public static func addNetworkAvailabilityObserver(_ observer: ZMNetworkAvailabilityObserver, userSession: ZMUserSession) -> Any {
        return NotificationInContext.addObserver(name: name,
                                                 context: userSession)
        {
            [weak observer] note in
            observer?.didChangeAvailability(newState: note.userInfo[stateKey] as! ZMNetworkState)
        }
    }
    
    public static func notify(networkState: ZMNetworkState, userSession: ZMUserSession) {
        NotificationInContext(name: name, context: userSession, userInfo: [stateKey: networkState]).post()
    }

}

@objc public protocol ZMNetworkAvailabilityObserver: NSObjectProtocol {
    func didChangeAvailability(newState: ZMNetworkState)
}


// MARK: - Typing
private let typingNotificationUsersKey = "typingUsers"

public extension ZMConversation {

    @objc public func addTypingObserver(_ observer: ZMTypingChangeObserver) -> Any {
        return NotificationInContext.addObserver(name: ZMConversation.typingNotificationName,
                                                 context: self.managedObjectContext!.notificationContext,
                                                 object: self)
        {
            [weak observer, weak self] note in
            guard let `self` = self else { return }
            
            let users = note.userInfo[typingNotificationUsersKey] as? Set<ZMUser> ?? Set()
            observer?.typingDidChange(conversation: self, typingUsers: users)
        }
    }
    
    @objc public func notifyTyping(typingUsers: Set<ZMUser>) {
        NotificationInContext(name: ZMConversation.typingNotificationName,
                              context: self.managedObjectContext!.notificationContext,
                              object: self,
                              userInfo: [typingNotificationUsersKey: typingUsers]).post()
    }
}


@objc public protocol ZMTypingChangeObserver: NSObjectProtocol {
    
    func typingDidChange(conversation: ZMConversation, typingUsers: Set<ZMUser>)
}

// MARK: - Connection limit reached
@objc public protocol ZMConnectionLimitObserver: NSObjectProtocol {
    
    func connectionLimitReached()
}


@objcMembers public class ZMConnectionLimitNotification : NSObject {

    private static let name = Notification.Name(rawValue: "ZMConnectionLimitReachedNotification")
    
    public static func addConnectionLimitObserver(_ observer: ZMConnectionLimitObserver, context: NSManagedObjectContext) -> Any {
        return NotificationInContext.addObserver(name: self.name, context: context.notificationContext) {
            [weak observer] _ in
            observer?.connectionLimitReached()
        }
    }
    
    @objc(notifyInContext:)
    public static func notify(context: NSManagedObjectContext) {
        NotificationInContext(name: self.name, context: context.notificationContext).post()
    }
}



