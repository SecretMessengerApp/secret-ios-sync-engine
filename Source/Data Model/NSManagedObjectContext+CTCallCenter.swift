//

import Foundation
import CoreTelephony

public extension NSManagedObjectContext {
    
    private static let WireCallCenterKey = "WireCallCenterKey"

    @objc
    var zm_callCenter : WireCallCenterV3? {
        
        get {
            precondition(zm_isUserInterfaceContext, "callCenter can only be accessed on the ui context")
            return userInfo[NSManagedObjectContext.WireCallCenterKey] as? WireCallCenterV3
        }
        
        set {
            precondition(zm_isUserInterfaceContext, "callCenter can only be accessed on the ui context")
            userInfo[NSManagedObjectContext.WireCallCenterKey] = newValue
        }
        
    }
    
    private static let ConstantBitRateAudioKey = "ConstantBitRateAudioKey"
    
    @objc
    var zm_useConstantBitRateAudio : Bool {
        
        get {
            precondition(zm_isUserInterfaceContext, "zm_useConstantBitRateAudio can only be accessed on the ui context")
            return userInfo[NSManagedObjectContext.ConstantBitRateAudioKey] as? Bool ?? false
        }
        
        set {
            precondition(zm_isUserInterfaceContext, "zm_useConstantBitRateAudio can only be accessed on the ui context")
            userInfo[NSManagedObjectContext.ConstantBitRateAudioKey] = newValue
        }
        
    }
    
}
