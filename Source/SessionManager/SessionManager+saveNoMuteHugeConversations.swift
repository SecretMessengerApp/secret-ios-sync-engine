
import Foundation

extension SessionManager {
    
    @objc func saveNoMuteHugeConversations() {
        if #available(iOS 13.3, *) {
            return
        }
        for (_, session) in backgroundUserSessions {
            if session.isAuthenticated() {
                session.saveHugeGroup()
            }
        }
    }
    
}
