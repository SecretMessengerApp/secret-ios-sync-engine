//

import Foundation

fileprivate let AVSLogMessageNotification = Notification.Name("AVSLogMessageNotification")

@objc
public protocol AVSLogger: class {
    
    @objc(logMessage:)
    func log(message : String)
    
}

public extension SessionManager {
    
    @objc
    static func addLogger(_ logger : AVSLogger) -> Any {
        return SelfUnregisteringNotificationCenterToken(NotificationCenter.default.addObserver(forName: AVSLogMessageNotification, object: nil, queue: nil) { [weak logger] (note) in
            guard let message = note.userInfo?["message"] as? String else { return }
            logger?.log(message: message)
        })
    }
    
    @objc
    static func logAVS(message: String) {
        NotificationCenter.default.post(name: AVSLogMessageNotification, object: nil, userInfo: ["message" : message])
    }
    
}
