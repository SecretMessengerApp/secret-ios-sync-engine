//

import Foundation

extension ZMOperationLoop: OperationStatusDelegate {
    
    public func operationStatus(didChangeState state: SyncEngineOperationState) {
        
        if state == .foreground {
            transportSession.enterForeground()
        } else {
            transportSession.enterBackground()
        }
        
        transportSession.pushChannel.keepOpen = state == .foreground || state == .backgroundCall
    }
    
}
