//

import Foundation
import WireDataModel

/**
 * Creates call centers.
 */

@objcMembers public class WireCallCenterV3Factory : NSObject {

    /// The class to use when creating a call center,
    public static var wireCallCenterClass : WireCallCenterV3.Type = WireCallCenterV3.self

    /// The class to use when creating a voice channel.
    public static var voiceChannelClass : VoiceChannel.Type = VoiceChannelV3.self

    /**
     * Creates a call center with the specified information.
     * - parameter userId: The identifier of the current signed-in user.
     * - parameter clientId: The identifier of the current client on the user's account.
     * - parameter uiMOC: The Core Data context to use to coordinate events.
     * - parameter flowManager: The object that controls media flow.
     * - parameter analytics: The object to use to record stats about the call. Defaults to `nil`.
     * - parameter transport: The object that performs network requests when the call center requests them.
     * - returns: The call center to use for the given configuration.
     */

    public class func callCenter(withUserId userId: UUID, clientId: String, uiMOC: NSManagedObjectContext, flowManager: FlowManagerType, analytics: AnalyticsType? = nil, transport: WireCallCenterTransport) -> WireCallCenterV3 {
        if let wireCallCenter = uiMOC.zm_callCenter {
            return wireCallCenter
        } else {
            let newInstance = WireCallCenterV3Factory.wireCallCenterClass.init(userId: userId, clientId: clientId, uiMOC: uiMOC, flowManager: flowManager, analytics: analytics, transport: transport)
            newInstance.useConstantBitRateAudio = uiMOC.zm_useConstantBitRateAudio
            uiMOC.zm_callCenter = newInstance
            return newInstance
        }
    }
    
}
