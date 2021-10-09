//

import Foundation
import CoreData

extension NSManagedObjectContext : ZMSynchonizableKeyValueStore {
    
    public func store(value: PersistableInMetadata?, key: String) {
        self.setPersistentStoreMetadata(value, key: key)
    }
    
    public func storedValue(key: String) -> Any? {
        return self.persistentStoreMetadata(forKey: key)
    }
}
