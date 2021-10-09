// 


import Foundation
import WireDataModel

// MARK: - Error on context save debugging

public enum ContextType : String {
    case UI = "UI"
    case Sync = "Sync"
    case Search = "Search"
    case Other = "Other"
    case Msg = "Msg"
}

extension NSManagedObjectContext {
    
    var type : ContextType {
        if self.zm_isSyncContext {
            return .Sync
        }
        if self.zm_isUserInterfaceContext {
            return .UI
        }
        if self.zm_isSearchContext {
            return .Search
        }
        if self.zm_isMsgContext {
            return .Msg
        }
        return .Other
    }
}

extension ZMUserSession {
    
    public typealias SaveFailureCallback = (_ metadata: [String: Any], _ type: ContextType, _ error: NSError, _ userInfo: [String: Any]) -> ()
    
    /// Register a handle for monitoring when one of the manage object contexts fails
    /// to save and is rolled back. The call is invoked on the context queue, so it might not be on the main thread
    public func registerForSaveFailure(handler: @escaping SaveFailureCallback) {
        self.managedObjectContext.errorOnSaveCallback = { (context, error) in
            let metadata : [String: Any] = context.persistentStoreCoordinator!.persistentStores[0].metadata as [String: Any]
            let type = context.type
            let userInfo : [String: Any] = context.userInfo.asDictionary() as! [String: Any]
            handler(metadata, type, error, userInfo)
        }
        self.syncManagedObjectContext.performGroupedBlock {
            self.syncManagedObjectContext.errorOnSaveCallback = { (context, error) in
                let metadata : [String: Any] = context.persistentStoreCoordinator!.persistentStores[0].metadata as [String: Any]
                let type = context.type
                let userInfo : [String: Any] = context.userInfo.asDictionary() as! [String: Any]
                handler(metadata, type, error, userInfo)
            }
        }
    }
}
