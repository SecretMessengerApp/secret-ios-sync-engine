//

import Foundation

extension PushNotificationCategory {
    func addMuteIfNeeded(hasTeam: Bool) -> PushNotificationCategory {
        guard !hasTeam else {
            return self
        }
        
        switch self {
        case .conversation:
            return .conversationWithMute
        case .conversationWithLike:
            return .conversationWithLikeAndMute
        default:
            return self
        }
    }
}

extension LocalNotificationType {
    
    func category(hasTeam: Bool) -> String {
        let category: PushNotificationCategory
        
        switch self {
        case .calling(let callState):
            switch (callState) {
            case .incoming:
                category = .incomingCall
            case .terminating(reason: .timeout):
                category = .missedCall
            default :
                category = PushNotificationCategory.conversation.addMuteIfNeeded(hasTeam: hasTeam)
            }
        case .event(let eventType):
            switch eventType {
            case .connectionRequestPending, .conversationCreated:
                category = .connect
            default:
                category = PushNotificationCategory.conversation.addMuteIfNeeded(hasTeam: hasTeam)
            }
        case .message(let contentType):
            switch contentType {
            case .audio, .video, .fileUpload, .image, .text, .location:
                category = PushNotificationCategory.conversation.addMuteIfNeeded(hasTeam: hasTeam)
            case .hidden:
                category = .alert
            default:
                category = PushNotificationCategory.conversation.addMuteIfNeeded(hasTeam: hasTeam)
            }
        case .failedMessage:
            category = PushNotificationCategory.conversation.addMuteIfNeeded(hasTeam: hasTeam)
        case .availabilityBehaviourChangeAlert:
            category = PushNotificationCategory.alert
        }
        
        return category.rawValue
    }
    
    var sound: NotificationSound {
        switch self {
        case .calling(let callState):
            switch callState {
            case .incoming:
                return .call
            default:
                return .newMessage
            }
        case .event:
            return .newMessage
        case .message(let contentType):
            switch contentType {
            case .knock:
                return .ping
            default:
                return .newMessage
            }
        case .failedMessage, .availabilityBehaviourChangeAlert:
            return .newMessage
        }
    }
    
}
