//

import Foundation

extension SessionManager {
    
    /// Forwards the Handoff/CallKit activity that user would like to continue in the app
    @objc(continueUserActivity:restorationHandler:)
    public func continueUserActivity(_ userActivity : NSUserActivity, restorationHandler: ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if #available(iOS 10.0, *) {
            return callKitManager?.continueUserActivity(userActivity) ?? false
        } else {
            return false
        }
    }
    
}
