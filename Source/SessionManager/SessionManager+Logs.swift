//

import Foundation

extension SessionManager {
    
    static func enableLogsByEnvironmentVariable() {
        if let tags = ProcessInfo.processInfo.environment["ZMLOG_TAGS"] {
            for tag in (tags.split { $0 == "," }.map { String($0) }) {
                ZMSLog.set(level: .debug, tag: tag)
            }
        }
    }
    
}
