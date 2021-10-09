//

import Foundation
import CoreData
import WireDataModel

/// Abstraction of queue
public protocol GenericAsyncQueue {
    
    func performAsync(_ block: @escaping () -> ())
}

extension DispatchQueue: GenericAsyncQueue {
    
    public func performAsync(_ block: @escaping () -> ()) {
        self.async(execute: block)
    }
}

extension NSManagedObjectContext: GenericAsyncQueue {
    
    public func performAsync(_ block: @escaping () -> ()) {
        self.performGroupedBlock(block)
    }
}

@objc public protocol PostLoginAuthenticationObserver: NSObjectProtocol {
    
    /// Invoked when the authentication has proven invalid
    @objc optional func authenticationInvalidated(_ error: NSError, accountId : UUID)
    
    /// Invoked when a client is successfully registered
    @objc optional func clientRegistrationDidSucceed(accountId : UUID)
    
    /// Invoked when there was an error registering the client
    @objc optional func clientRegistrationDidFail(_ error: NSError, accountId : UUID)
    
    /// Account was successfully deleted
    @objc optional func accountDeleted(accountId : UUID)
    
    /// Invoked when the user successfully logged out
    @objc optional func userDidLogout(accountId: UUID)
    
}

/// Authentication events that could happen after login
enum PostLoginAuthenticationEvent {
    
    /// The cookie is not valid anymore
    case authenticationInvalidated(error: NSError)
    
    /// Client failed to register
    case clientRegistrationDidFail(error: NSError)
    
    /// Client registered client
    case clientRegistrationDidSucceed
    
    /// Account was successfully deleted on the backend
    case accountDeleted
    
    /// User did logout
    case userDidLogout
}

@objcMembers public class PostLoginAuthenticationNotification : NSObject {
    
    static private let name = Notification.Name(rawValue: "PostLoginAuthenticationNotification")
    static private let eventKey = "event"
    
    fileprivate static func notify(event: PostLoginAuthenticationEvent, context: NSManagedObjectContext) {
        NotificationInContext(name: self.name, context: context.notificationContext, object:context, userInfo: [self.eventKey: event]).post()
    }
    
    static public func addObserver(_ observer: PostLoginAuthenticationObserver,
                                   context: NSManagedObjectContext) -> Any {
         return self.addObserver(observer, context: context, queue: context)
    }
    
    static public func addObserver(_ observer: PostLoginAuthenticationObserver,
                                   queue: ZMSGroupQueue) -> Any {
        return self.addObserver(observer, context: nil, queue: queue)
    }

    static public func addObserver(_ observer: PostLoginAuthenticationObserver) -> Any {
        return self.addObserver(observer, context: nil, queue: DispatchGroupQueue(queue: DispatchQueue.main))
    }

    static private func addObserver(_ observer: PostLoginAuthenticationObserver, context: NSManagedObjectContext? = nil, queue: ZMSGroupQueue) -> Any {
        
        let token = NotificationInContext.addUnboundedObserver(name: name, context: context?.notificationContext, queue:nil) { [weak observer] (note) in            
            guard
                let event = note.userInfo[eventKey] as? PostLoginAuthenticationEvent,
                let observer = observer,
                let context = note.object as? NSManagedObjectContext else { return }
            
            context.performGroupedBlock {
                guard let accountId = ZMUser.selfUser(in: context).remoteIdentifier else {
                    return
                }
                
                queue.performGroupedBlock {
                    switch event {
                    case .authenticationInvalidated(let error):
                        observer.authenticationInvalidated?(error, accountId: accountId)
                    case .clientRegistrationDidFail(let error):
                        observer.clientRegistrationDidFail?(error, accountId: accountId)
                    case .clientRegistrationDidSucceed:
                        observer.clientRegistrationDidSucceed?(accountId: accountId)
                    case .accountDeleted:
                        observer.accountDeleted?(accountId: accountId)
                    case .userDidLogout:
                        observer.userDidLogout?(accountId: accountId)
                    }
                }
            }
        }
                
        return SelfUnregisteringNotificationCenterToken(token)
    }
    
    static public func addObserver(_ observer: PostLoginAuthenticationObserver, userSession: ZMUserSession) -> Any {
        return self.addObserver(observer, context: userSession.managedObjectContext)
    }
}

@objc public extension PostLoginAuthenticationNotification {
    
    static func notifyAuthenticationInvalidated(error: NSError, context: NSManagedObjectContext) {
        self.notify(event: .authenticationInvalidated(error: error), context: context)
    }
    
    @objc(notifyClientRegistrationDidSucceedInContext:)
    static func notifyClientRegistrationDidSucceed(context: NSManagedObjectContext) {
        self.notify(event: .clientRegistrationDidSucceed, context: context)
    }
    
    static func notifyClientRegistrationDidFail(error: NSError, context: NSManagedObjectContext) {
        self.notify(event: .clientRegistrationDidFail(error: error), context: context)
    }
    
    @objc(notifyAccountDeletedInContext:)
    static func notifyAccountDeleted(context: NSManagedObjectContext) {
        self.notify(event: .accountDeleted, context: context)
    }
    
    @objc(notifyUserDidLogoutInContext:)
    static func notifyUserDidLogout(context: NSManagedObjectContext) {
        self.notify(event: .userDidLogout, context: context)
    }
}
