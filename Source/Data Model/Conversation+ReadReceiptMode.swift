////

import Foundation

public enum ReadReceiptModeError: Error {
    case invalidOperation
    case accessDenied
    case noConversation
    case unknown
    
    init?(response: ZMTransportResponse) {
        switch (response.httpStatus, response.payloadLabel()) {
        case (403, "access-denied"): self = .accessDenied
        case (404, "no-conversation"): self = .noConversation
        case (400..<499, _): self = .unknown
        default: return nil
        }
    }
}

extension ZMConversation {
    
    /// Enable or disable read receipts in a group conversation
    public func setEnableReadReceipts(_ enabled: Bool, in userSession: ZMUserSession, _ completion: @escaping (VoidResult) -> Void) {
        guard conversationType == .group else { return  completion(.failure(ReadReceiptModeError.invalidOperation))}
        guard let conversationId = remoteIdentifier?.transportString() else { return completion(.failure(ReadReceiptModeError.noConversation)) }
        
        let payload = ["receipt_mode": enabled ? 1 : 0] as ZMTransportData
        let request = ZMTransportRequest(path: "/conversations/\(conversationId)/receipt-mode", method: .methodPUT, payload: payload)
        
        request.add(ZMCompletionHandler(on: managedObjectContext!) { response in
            if response.httpStatus == 200, let event = response.updateEvent {
                userSession.syncManagedObjectContext.performGroupedBlock {
                    userSession.operationLoop.syncStrategy.process(updateEvents: [event], ignoreBuffer: false)
                    userSession.managedObjectContext.performGroupedBlock {
                        completion(.success)
                    }
                }
            } else if response.httpStatus == 204 {
                self.hasReadReceiptsEnabled = enabled
                completion(.success)
            } else {
                completion(.failure(ReadReceiptModeError(response: response) ?? .unknown))
            }
        })
        
        userSession.transportSession.enqueueOneTime(request)
    }
    
}
