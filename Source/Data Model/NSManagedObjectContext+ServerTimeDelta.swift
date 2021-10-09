//

import Foundation


public extension NSManagedObjectContext {
    
    private static let ServerTimeDeltaKey = "ServerTimeDeltaKey"
    
    @objc
    var serverTimeDelta : TimeInterval {
        
        get {
            precondition(!zm_isUserInterfaceContext, "serverTimeDelta can not be accessed on the ui context")
            return userInfo[NSManagedObjectContext.ServerTimeDeltaKey] as? TimeInterval ?? 0
        }
        
        set {
            precondition(!zm_isUserInterfaceContext, "serverTimeDelta can not be accessed on the ui context")
            userInfo[NSManagedObjectContext.ServerTimeDeltaKey] = newValue
        }
        
    }
        
}
