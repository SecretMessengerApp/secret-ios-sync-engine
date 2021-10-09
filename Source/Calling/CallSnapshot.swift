//

import Foundation

/**
 * The snapshot of the state of a call.
 */

struct CallSnapshot {
    let callParticipants: CallParticipantsSnapshot
    let callState: CallState
    let callStarter: UUID
    let isVideo: Bool
    let isGroup: Bool
    let isConstantBitRate: Bool
    let videoState: VideoState
    let networkQuality: NetworkQuality
    var conversationObserverToken : NSObjectProtocol?

    /**
     * Updates the snapshot with the new state of the call.
     * - parameter callState: The new state of the call computed from AVS.
     */

    func update(with callState: CallState) -> CallSnapshot {
        return CallSnapshot(callParticipants: callParticipants,
                            callState: callState,
                            callStarter: callStarter,
                            isVideo: isVideo,
                            isGroup: isGroup,
                            isConstantBitRate: isConstantBitRate,
                            videoState: videoState,
                            networkQuality: networkQuality,
                            conversationObserverToken: conversationObserverToken)
    }

    /**
     * Updates the snapshot with the CBR state.
     * - parameter enabled: Whether constant bitrate was enabled.
     */

    func updateConstantBitrate(_ enabled: Bool) -> CallSnapshot {
        return CallSnapshot(callParticipants: callParticipants,
                            callState: callState,
                            callStarter: callStarter,
                            isVideo: isVideo,
                            isGroup: isGroup,
                            isConstantBitRate: enabled,
                            videoState: videoState,
                            networkQuality: networkQuality,
                            conversationObserverToken: conversationObserverToken)
    }

    /**
     * Updates the snapshot with the new video state.
     * - parameter videoState: The new video state.
     */

    func updateVideoState(_ videoState: VideoState) -> CallSnapshot {
        return CallSnapshot(callParticipants: callParticipants,
                            callState: callState,
                            callStarter: callStarter,
                            isVideo: isVideo,
                            isGroup: isGroup,
                            isConstantBitRate: isConstantBitRate,
                            videoState: videoState,
                            networkQuality: networkQuality,
                            conversationObserverToken: conversationObserverToken)
    }

    /**
     * Updates the snapshot with the new network condition.
     * - parameter networkCondition: The new network condition.
     */

    func updateNetworkQuality(_ networkQuality: NetworkQuality) -> CallSnapshot {
        return CallSnapshot(callParticipants: callParticipants,
                            callState: callState,
                            callStarter: callStarter,
                            isVideo: isVideo,
                            isGroup: isGroup,
                            isConstantBitRate: isConstantBitRate,
                            videoState: videoState,
                            networkQuality: networkQuality,
                            conversationObserverToken: conversationObserverToken)
    }

}
