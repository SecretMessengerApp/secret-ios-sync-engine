//

import Foundation

@objc
public protocol CallNotificationStyleProvider: class {
    
    var callNotificationStyle: CallNotificationStyle { get }
    
}

@objc extension ZMUserSession: CallNotificationStyleProvider {
    
    public var callCenter : WireCallCenterV3? {
        return managedObjectContext.zm_callCenter
    }
    
    public var callNotificationStyle : CallNotificationStyle {
        return sessionManager?.callNotificationStyle ?? .pushNotifications
    }
    
    internal var callKitManager : CallKitManager? {
        return sessionManager?.callKitManager
    }
    
    @objc var useConstantBitRateAudio : Bool {
        set {
            managedObjectContext.zm_useConstantBitRateAudio = newValue
            callCenter?.useConstantBitRateAudio = newValue
        }
        
        get {
            return managedObjectContext.zm_useConstantBitRateAudio
        }
    }
    
}
