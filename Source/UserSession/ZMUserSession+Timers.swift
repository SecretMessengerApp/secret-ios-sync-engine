////

import Foundation
import WireDataModel

extension ZMUserSession {
    @objc public func startEphemeralTimers() {
        syncManagedObjectContext?.performGroupedBlock {
            self.syncManagedObjectContext?.zm_createMessageObfuscationTimer()
        }
        managedObjectContext?.zm_createMessageDeletionTimer()
    }
    
    @objc public func stopEphemeralTimers() {
        syncManagedObjectContext?.performGroupedBlock {
            self.syncManagedObjectContext?.zm_teardownMessageObfuscationTimer()
        }
        managedObjectContext?.zm_teardownMessageDeletionTimer()
    }

}
