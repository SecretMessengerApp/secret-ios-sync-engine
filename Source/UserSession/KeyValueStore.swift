//

import Foundation


@objc(ZMKeyValueStore) public protocol KeyValueStore : NSObjectProtocol {

    func store(value: PersistableInMetadata?, key: String)
    func storedValue(key: String) -> Any?
    
}
