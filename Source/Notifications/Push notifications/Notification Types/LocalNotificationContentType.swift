//

import Foundation

public enum LocalNotificationEventType {
    case connectionRequestAccepted, connectionRequestPending, newConnection, conversationCreated, conversationDeleted
}

public enum LocalNotificationContentType : Equatable {
    
    case undefined
    case text(String, isMention: Bool, isReply: Bool)
    case image
    case video
    case audio
    case location
    case fileUpload
    case knock
    case reaction(emoji: String)
    case hidden
    case ephemeral(isMention: Bool, isReply: Bool)
    case participantsRemoved
    case participantsAdded
    case messageTimerUpdate(String?)

    static func typeForMessage(_ message: ZMConversationMessage) -> LocalNotificationContentType? {
        
        if message.isEphemeral {
            if let messageData = message.textMessageData {
                return .ephemeral(isMention: messageData.isMentioningSelf, isReply: messageData.isQuotingSelf)
            }
            else {
                return .ephemeral(isMention: false, isReply: false)
            }
        }
        
        if  let messageData = message.textMessageData,
            let text = messageData.messageText ,
            !text.isEmpty {
            print("text: \(text)")
            return .text(text, isMention: messageData.isMentioningSelf, isReply: messageData.isQuotingSelf)
        }
        
        if message.knockMessageData != nil {
            return .knock
        }
        
        if message.imageMessageData != nil {
            return .image
        }
        
        if let fileData = message.fileMessageData {
            if fileData.isAudio {
                return .audio
            }
            else if fileData.isVideo {
                return .video
            }
            return .fileUpload
        }
        
        if message.locationMessageData != nil {
            return .location
        }
        
        if let systemMessageData = message.systemMessageData {
            switch systemMessageData.systemMessageType {
            case .participantsAdded:
                return .participantsAdded
            case .participantsRemoved:
                return .participantsRemoved
            case .messageTimerUpdate:
                let value = MessageDestructionTimeoutValue(rawValue: TimeInterval(systemMessageData.messageTimer?.doubleValue ?? 0))
                if value == .none {
                    return .messageTimerUpdate(nil)
                } else {
                    return .messageTimerUpdate(value.displayString)
                }
            case .serviceMessage:
                if let systemMessage = message as? ZMSystemMessage,
                    let serviceMessage = systemMessage.serviceMessage,
                    let text = serviceMessage.text {
                   return .text(text, isMention: false, isReply: false)
                } else {
                   return nil
                }
            default:
                return nil
            }
        }
        
        return .undefined
    }
    
}

public func ==(rhs: LocalNotificationContentType, lhs: LocalNotificationContentType) -> Bool {
    switch (rhs, lhs) {
    case (.text(let left), .text(let right)):
        return left == right
    case (.image, .image), (.video, .video), (.audio, .audio), (.location, .location), (.fileUpload, .fileUpload), (.knock, .knock), (.undefined, .undefined), (.reaction, .reaction), (.messageTimerUpdate, .messageTimerUpdate):
        return true
    default:
        return false
    }
}


