//

import Foundation

public typealias AsyncAction = (_ whenDone: @escaping ()->()) -> ()

extension DispatchQueue {
    // Dispatches the @c action on the queue in the serial way, waiting for the completion call (whenDone).
    public func serialAsync(do action: @escaping AsyncAction) {
        self.async {
            let loadingGroup = DispatchGroup()
            loadingGroup.enter()
            
            DispatchQueue.main.async {
                action {
                    loadingGroup.leave()
                }
            }
            
            loadingGroup.wait()
        }
        
    }
}
