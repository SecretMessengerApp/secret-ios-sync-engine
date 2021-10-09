//

import Foundation

public extension LocalNotificationDispatcher {
    
    func process(callState: CallState, in conversation: ZMConversation, caller: ZMUser) {
        // missed call notification are handled separately
        // but if call was answered elsewhere then proceed
        switch callState {
        case .terminating(reason: let reason):
            switch reason {
            case .anweredElsewhere, .rejectedElsewhere: break
            default: return
            }
        default: break
        }
        
        let note = ZMLocalNotification(callState: callState, conversation: conversation, caller: caller)
        callingNotifications.cancelNotifications(conversation)
        note.apply(scheduleLocalNotification)
        note.apply(callingNotifications.addObject)
    }
    
    func processMissedCall(in conversation: ZMConversation, caller: ZMUser) {
        let note = ZMLocalNotification(callState: .terminating(reason: .canceled), conversation: conversation, caller: caller)
        callingNotifications.cancelNotifications(conversation)
        note.apply(scheduleLocalNotification)
        note.apply(callingNotifications.addObject)
    }
}
