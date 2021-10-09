//

import Foundation
import avs

public enum VoiceChannelV3Error: LocalizedError {
    case switchToVideoNotAllowed

    public var errorDescription: String? {
        switch self {
        case .switchToVideoNotAllowed:
            return "Switch to video is not allowed"
        }
    }
}

public class VoiceChannelV3 : NSObject, VoiceChannel {

    public var callCenter: WireCallCenterV3? {
        return self.conversation?.managedObjectContext?.zm_callCenter
    }
    
    /// The date and time of current call start
    public var callStartDate: Date? {
        return self.callCenter?.establishedDate
    }
    
    weak public var conversation: ZMConversation?
    
    public var participants: [CallParticipant] {
        guard let callCenter = callCenter, let conversationId = conversation?.remoteIdentifier else { return [] }
        
        return callCenter.callParticipants(conversationId: conversationId)
    }
    
    public required init(conversation: ZMConversation) {
        self.conversation = conversation
        super.init()
    }
    
    public var state: CallState {
        if let conversation = conversation, let remoteIdentifier = conversation.remoteIdentifier, let callCenter = self.callCenter {
            return callCenter.callState(conversationId: remoteIdentifier)
        } else {
            return .none
        }
    }
    
    public var isVideoCall: Bool {
        guard let remoteIdentifier = conversation?.remoteIdentifier else { return false }
        
        return self.callCenter?.isVideoCall(conversationId: remoteIdentifier) ?? false
    }
    
    public var isConstantBitRateAudioActive: Bool {
        guard let remoteIdentifier = conversation?.remoteIdentifier else { return false }
        
        return self.callCenter?.isContantBitRate(conversationId: remoteIdentifier) ?? false
    }

    public var networkQuality: NetworkQuality {
        guard let remoteIdentifier = conversation?.remoteIdentifier, let callCenter = self.callCenter else { return .normal }

        return callCenter.networkQuality(conversationId: remoteIdentifier)
    }
    
    public var initiator: UserType? {
        guard let context = conversation?.managedObjectContext,
              let convId = conversation?.remoteIdentifier,
              let userId = self.callCenter?.initiatorForCall(conversationId: convId)
        else {
            return nil
        }
        return ZMUser.fetch(withRemoteIdentifier: userId, in: context)
    }
    
    public var videoState: VideoState {
        get {
            guard let remoteIdentifier = conversation?.remoteIdentifier else { return .stopped }
            
            return self.callCenter?.videoState(conversationId: remoteIdentifier) ?? .stopped
        }
        set {
            guard let remoteIdentifier = conversation?.remoteIdentifier else { return }
            
            callCenter?.setVideoState(conversationId: remoteIdentifier, videoState: newValue)
        }
    }
    
    public func setVideoCaptureDevice(_ device: CaptureDevice) throws {
        guard let conversationId = conversation?.remoteIdentifier else { throw VoiceChannelV3Error.switchToVideoNotAllowed }
        
        self.callCenter?.setVideoCaptureDevice(device, for: conversationId)
    }
    
    public var muted: Bool {
        get {
            return callCenter?.muted ?? false
        }
        set {
            callCenter?.muted = newValue
        }
    }
    
}

extension VoiceChannelV3 : CallActions {
    
    public func mute(_ muted: Bool, userSession: ZMUserSession) {
        if userSession.callNotificationStyle == .callKit, #available(iOS 10.0, *) {
            userSession.callKitManager?.requestMuteCall(in: conversation!, muted: muted)
        } else {
            self.muted = muted
        }
    }
    
    public func continueByDecreasingConversationSecurity(userSession: ZMUserSession) {
        guard let conversation = conversation else { return }
        conversation.acknowledgePrivacyWarning(withResendIntent: false)
    }
    
    public func leaveAndDecreaseConversationSecurity(userSession: ZMUserSession) {
        guard let conversation = conversation else { return }
        conversation.acknowledgePrivacyWarning(withResendIntent: false)
        userSession.syncManagedObjectContext.performGroupedBlock {
            let conversationId = conversation.objectID
            if let syncConversation = (try? userSession.syncManagedObjectContext.existingObject(with: conversationId)) as? ZMConversation {
                userSession.syncStrategy?.callingRequestStrategy.dropPendingCallMessages(for: syncConversation)
            }
        }
        leave(userSession: userSession, completion: nil)
    }
    
    public func join(video: Bool, userSession: ZMUserSession) -> Bool {
        if userSession.callNotificationStyle == .callKit, #available(iOS 10.0, *) {
            userSession.callKitManager?.requestJoinCall(in: conversation!, video: video)
            return true
        } else {
            return join(video: video)
        }
    }
    
    public func leave(userSession: ZMUserSession, completion: (() -> ())?) {
        if userSession.callNotificationStyle == .callKit, #available(iOS 10.0, *) {
            userSession.callKitManager?.requestEndCall(in: conversation!, completion: completion)
        } else {
            leave()
            completion?()
        }
    }
    
}

extension VoiceChannelV3 : CallActionsInternal {
    
    public func join(video: Bool) -> Bool {
        guard let conversation = conversation else { return false }
        
        var joined = false
        
        switch state {
        case .incoming(video: _, shouldRing: _, degraded: let degraded):
            if !degraded {
                joined = callCenter?.answerCall(conversation: conversation, video: video) ?? false
            }
        default:
            joined = self.callCenter?.startCall(conversation: conversation, video: video) ?? false
        }
        
        return joined
    }
    
    public func leave() {
        guard let conv = conversation,
              let remoteID = conv.remoteIdentifier
        else { return }
        
        switch state {
        case .incoming:
            callCenter?.rejectCall(conversationId: remoteID)
        default:
            callCenter?.closeCall(conversationId: remoteID)
        }
    }
    
}

extension VoiceChannelV3 : CallObservers {

    public func addNetworkQualityObserver(_ observer: NetworkQualityObserver) -> Any {
        return WireCallCenterV3.addNetworkQualityObserver(observer: observer, for: conversation!, context: conversation!.managedObjectContext!)
    }
    
    /// Add observer of voice channel state. Returns a token which needs to be retained as long as the observer should be active.
    public func addCallStateObserver(_ observer: WireCallCenterCallStateObserver) -> Any {
        return WireCallCenterV3.addCallStateObserver(observer: observer, for: conversation!, context: conversation!.managedObjectContext!)
    }
    
    /// Add observer of voice channel participants. Returns a token which needs to be retained as long as the observer should be active.
    public func addParticipantObserver(_ observer: WireCallCenterCallParticipantObserver) -> Any {
        return WireCallCenterV3.addCallParticipantObserver(observer: observer, for: conversation!, context: conversation!.managedObjectContext!)
    }
    
    /// Add observer of voice gain. Returns a token which needs to be retained as long as the observer should be active.
    public func addVoiceGainObserver(_ observer: VoiceGainObserver) -> Any {
        return WireCallCenterV3.addVoiceGainObserver(observer: observer, for: conversation!, context: conversation!.managedObjectContext!)
    }
        
    /// Add observer of constant bit rate audio. Returns a token which needs to be retained as long as the observer should be active.
    public func addConstantBitRateObserver(_ observer: ConstantBitRateAudioObserver) -> Any {
        return WireCallCenterV3.addConstantBitRateObserver(observer: observer, context: conversation!.managedObjectContext!)
    }
    
    /// Add observer of the state of all voice channels. Returns a token which needs to be retained as long as the observer should be active.
    public class func addCallStateObserver(_ observer: WireCallCenterCallStateObserver, userSession: ZMUserSession) -> Any {
        return WireCallCenterV3.addCallStateObserver(observer: observer, context: userSession.managedObjectContext)
    }
    
    /// Add observer of the mute state. Returns a token which needs to be retained as long as the observer should be active.
    public func addMuteStateObserver(_ observer: MuteStateObserver) -> Any {
        return WireCallCenterV3.addMuteStateObserver(observer: observer, context: conversation!.managedObjectContext!)
    }
}
