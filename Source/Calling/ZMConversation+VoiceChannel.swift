//

import Foundation

private var voiceChannelAssociatedKey: UInt8 = 0

public extension ZMConversation {
    
    /// NOTE: this object is transient, and will be re-created periodically. Do not hold on to this object, hold on to the owning conversation instead.
    var voiceChannel : VoiceChannel? {
        get {
            guard conversationType == .oneOnOne || conversationType == .group else { return nil }
            
            if let voiceChannel = objc_getAssociatedObject(self, &voiceChannelAssociatedKey) as? VoiceChannel {
                return voiceChannel
            } else {
                let voiceChannel = WireCallCenterV3Factory.voiceChannelClass.init(conversation: self)
                objc_setAssociatedObject(self, &voiceChannelAssociatedKey, voiceChannel, .OBJC_ASSOCIATION_RETAIN)
                return voiceChannel
            }
        }
    }
    
}
