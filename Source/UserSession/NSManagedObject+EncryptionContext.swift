//

import Foundation
import WireDataModel

extension NSManagedObjectContext {
    
    @objc public func deleteAndCreateNewEncryptionContext() {
        self.zm_cryptKeyStore.deleteAndCreateNewBox()
    }
}
