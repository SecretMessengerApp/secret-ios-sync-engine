//


import Foundation
import WireDataModel

@objc
public final class ConversationStatusStrategy : ZMObjectSyncStrategy, ZMContextChangeTracker {

    let lastReadKey = "lastReadServerTimeStamp"
    let clearedKey = "clearedTimeStamp"
    
    public func objectsDidChange(_ objects: Set<NSManagedObject>) {
        var didUpdateConversation = false
        objects.forEach{
            if let conv = $0 as? ZMConversation {
                if conv.hasLocalModifications(forKey: lastReadKey){
                    conv.resetLocallyModifiedKeys(Set(arrayLiteral: lastReadKey))
                    ZMConversation.appendSelfConversation(withLastReadOf: conv)
                    didUpdateConversation = true
                }
                if conv.hasLocalModifications(forKey: clearedKey) {
                    conv.resetLocallyModifiedKeys(Set(arrayLiteral: clearedKey))
                    conv.deleteOlderMessages()
                    ZMConversation.appendSelfConversation(withClearedOf: conv)
                    didUpdateConversation = true
                }
            }
        }
        
        if didUpdateConversation {
            self.managedObjectContext?.enqueueDelayedSave()
        }
    }
    
    public func fetchRequestForTrackedObjects() -> NSFetchRequest<NSFetchRequestResult>? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ZMConversation.entityName())
        return request
    }
    
    public func addTrackedObjects(_ objects: Set<NSManagedObject>) {
        objectsDidChange(objects)
    }
    
}
