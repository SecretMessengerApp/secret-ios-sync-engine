//

import Foundation

private let log = ZMSLog(tag: "Calling System Message")

/// Inserts a calling system message for V3 calls.
final class CallSystemMessageGenerator: NSObject {
    
    var startDateByConversation = [ZMConversation: Date]()
    var connectDateByConversation = [ZMConversation: Date]()

    public func appendSystemMessageIfNeeded(callState: CallState, conversation: ZMConversation, caller: ZMUser, timestamp: Date?, previousCallState: CallState?) -> ZMSystemMessage?{
        var systemMessage : ZMSystemMessage? = nil

        switch callState {
        case .outgoing:
            log.info("Setting call start date for \(conversation.displayName)")
            startDateByConversation[conversation] = Date()
        case .established:
            log.info("Setting call connect date for \(conversation.displayName)")
            connectDateByConversation[conversation] = Date()
        case .terminating(reason: let reason):
        systemMessage = appendCallEndedSystemMessage(reason: reason, conversation: conversation, caller: caller, timestamp: timestamp, previousCallState:previousCallState)
        case .none, .unknown, .answered, .establishedDataChannel, .incoming, .mediaStopped:
            break
        }
        return systemMessage
    }

    private func appendCallEndedSystemMessage(reason: CallClosedReason, conversation: ZMConversation, caller: ZMUser, timestamp: Date?, previousCallState: CallState?) -> ZMSystemMessage? {
        
        var systemMessage : ZMSystemMessage? = nil
        if let connectDate = connectDateByConversation[conversation] {
            let duration = -connectDate.timeIntervalSinceNow
            log.info("Appending performed call message: \(duration), \(caller.displayName), \"\(conversation.displayName)\"")
            systemMessage =  conversation.appendPerformedCallMessage(with: duration, caller: caller)
        }
        else {
            if caller.isSelfUser {
                log.info("Appending performed call message: \(caller.displayName), \"\(conversation.displayName)\"")
                systemMessage =  conversation.appendPerformedCallMessage(with: 0, caller: caller)
            } else if reason.isOne(of: .canceled, .timeout, .normal) {
                log.info("Appending missed call message: \(caller.displayName), \"\(conversation.displayName)\"")
                
                var isRelevant = true
                if case .incoming(video: _, shouldRing: false, degraded: _)? = previousCallState {
                    //Call was ignored by recipient
                    isRelevant = false
                }
                
                systemMessage = conversation.appendMissedCallMessage(fromUser: caller, at: timestamp ?? Date(), relevantForStatus: isRelevant)
            }
        }
        
        startDateByConversation[conversation] = nil
        connectDateByConversation[conversation] = nil
        return systemMessage
    }
    
}
