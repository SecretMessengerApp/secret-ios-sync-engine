//

import Foundation

private let log = ZMSLog(tag: "ConversationMessageDestructionTimeout")

public enum MessageDestructionTimerError: Error {
    case invalidOperation
    case accessDenied
    case noConversation
    case unknown
    
    init?(response: ZMTransportResponse) {
        switch (response.httpStatus, response.payloadLabel()) {
        case (403, "invalid-op"?): self = .invalidOperation
        case (403, "access-denied"): self = .accessDenied
        case (404, "no-conversation"): self = .noConversation
        case (400..<499, _): self = .unknown
        default: return nil
        }
    }
}

extension ZMTransportResponse {
    var updateEvent: ZMUpdateEvent? {
        return payload.flatMap(papply(flip(ZMUpdateEvent.init), nil))
    }
}

extension ZMConversation {

    /// Changes the conversation message destruction timeout
    public func setMessageDestructionTimeout(
        _ timeout: MessageDestructionTimeoutValue,
        in userSession: ZMUserSession, _
        completion: @escaping (VoidResult) -> Void
        ) {

        let request = MessageDestructionTimeoutRequestFactory.set(timeout: Int(timeout.rawValue), for: self)
        request.add(ZMCompletionHandler(on: managedObjectContext!) { response in
            if response.httpStatus.isOne(of: 200, 204),  let event = response.updateEvent {
                // Process `conversation.message-timer-update` event
                userSession.syncManagedObjectContext.performGroupedBlock {
                    userSession.operationLoop.syncStrategy.process(updateEvents: [event], ignoreBuffer: false)
                }
                completion(.success)
            } else {
                let error = WirelessLinkError(response: response) ?? .unknown
                log.debug("Error updating message destruction timeout \(error): \(response)")
                completion(.failure(error))
            }
        })
        
        userSession.transportSession.enqueueOneTime(request)
    }
    
}

fileprivate struct MessageDestructionTimeoutRequestFactory {
    
    static func set(timeout: Int, for conversation: ZMConversation) -> ZMTransportRequest {
        guard let identifier = conversation.remoteIdentifier?.transportString() else { fatal("conversation inserted on backend") }
        
        let payload: [AnyHashable: Any?]
        if timeout == 0 {
            payload = ["message_timer": nil]
        }
        else {
            // Backend expects the timer to be in miliseconds, we store it in seconds.
            let timeoutInMS: Int64 = Int64(timeout) * 1000
            payload = ["message_timer": timeoutInMS]
        }
        return .init(path: "/conversations/\(identifier)/message-timer", method: .methodPUT, payload: payload as ZMTransportData)
    }

}
