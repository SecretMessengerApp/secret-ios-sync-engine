//

import Foundation

@objcMembers public class UserExpirationObserver: NSObject, ZMTimerClient {
    internal private(set) var expiringUsers: Set<ZMUser> = Set()
    private var timerForUser: [ZMTimer: ZMUser] = [:]
    private let managedObjectContext: NSManagedObjectContext
    
    deinit {
        timerForUser.forEach { $0.key.cancel() }
    }
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    public func check(users: Set<ZMUser>) {
        let allWireless = Set(users.filter { $0.isWirelessUser }).subtracting(expiringUsers)
        
        let expired = Set(allWireless.filter { $0.isExpired })
        expiringUsers.subtract(expired)
        let notExpired = allWireless.subtracting(expired)
        
        expired.forEach { $0.needsToBeUpdatedFromBackend = true }
        notExpired.forEach {
            let timer = ZMTimer(target: self)!
            timer.fire(afterTimeInterval: $0.expiresAfter)
            timerForUser[timer] = $0
        }
        expiringUsers.formUnion(notExpired)
    }
    
    public func check(usersIn conversation: ZMConversation) {
        check(users: conversation.activeParticipants)
    }
    
    public func timerDidFire(_ timer: ZMTimer) {
        managedObjectContext.performGroupedBlock {
            guard let user = self.timerForUser[timer] else {
                fatal("Unknown timer: \(timer)")
            }
            
            user.needsToBeUpdatedFromBackend = true
            self.timerForUser[timer] = nil
            self.expiringUsers.remove(user)
        }
    }
}
