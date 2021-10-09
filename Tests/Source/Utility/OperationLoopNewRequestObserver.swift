//

import Foundation

class OperationLoopNewRequestObserver {
    
    var token : NSObjectProtocol?
    var notifications = [Notification]()
    fileprivate var notificationCenter = NotificationCenter.default
    fileprivate var newRequestNotification = "RequestAvailableNotification"
    
    init() {
        token = notificationCenter.addObserver(forName: Notification.Name(rawValue: newRequestNotification), object: nil, queue: .main) { [weak self] note in
            self?.notifications.append(note)
        }
    }
    
    deinit {
        notifications.removeAll()
        if let token = token {
            notificationCenter.removeObserver(token)
        }
    }
}
