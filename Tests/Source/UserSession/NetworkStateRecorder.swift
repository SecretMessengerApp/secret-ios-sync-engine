//

import Foundation

@objcMembers
public class NetworkStateRecorder : NSObject, ZMNetworkAvailabilityObserver {
    
    var stateChanges : [NSNumber] = []
    
    public func didChangeAvailability(newState: ZMNetworkState) {
        stateChanges.append(NSNumber(value: newState.rawValue))
    }
    
}
