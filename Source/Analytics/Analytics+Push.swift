//

import Foundation

extension AnalyticsType {
    
    public func tagActionOnPushNotification(conversation: ZMConversation?, action: ConversationMediaAction) {
        guard let conversation = conversation else { return }
        var attributes = conversation.ephemeralTrackingAttributes
        attributes["action"] = action.attributeValue
        attributes["conversation_type"] = conversation.conversationType.analyticsType
        attributes["with_service"] = conversation.includesServiceUser ? "true" : "false"
        tagEvent("contributed", attributes: attributes as! [String : NSObject])
    }
    
}

public extension ZMConversation {
    
    @objc public var ephemeralTrackingAttributes: [String: Any] {
        let ephemeral = messageDestructionTimeout != nil
        var attributes: [String: Any] = ["is_ephemeral": ephemeral]
        guard ephemeral else { return attributes }
        attributes["ephemeral_time"] = "\(Int(messageDestructionTimeoutValue))"
        return attributes
    }
    
    /// Whether the conversation includes at least 1 service user.
    @objc public var includesServiceUser: Bool {
        guard let participants = lastServerSyncedActiveParticipants.array as? [UserType] else { return false }
        return participants.any { $0.isServiceUser }
    }
}

extension ZMConversationType {
    
     var analyticsType : String {
        switch self {
        case .oneOnOne:
            return "one_to_one"
        case .group, .hugeGroup:
            return "group"
        default:
            return ""
        }
    }
}

@objc public enum ConversationMediaAction: UInt {
    case text, photo, audioCall, videoCall, gif, ping, fileTransfer, videoMessage, audioMessage, location
    
    public var attributeValue: String {
        switch self {
        case .text:         return "text"
        case .photo:        return "photo"
        case .audioCall:    return "audio_call"
        case .videoCall:    return "video_call"
        case .gif:          return "giphy"
        case .ping:         return "ping"
        case .fileTransfer: return "file"
        case .videoMessage: return "video"
        case .audioMessage: return "audio"
        case .location:     return "location"
        }
    }
}




