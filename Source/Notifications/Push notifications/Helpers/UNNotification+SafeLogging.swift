////

import Foundation

extension UNNotification: SafeForLoggingStringConvertible {
    public var safeForLoggingDescription: String {
        return "date:\(date) request_id:\(request.identifier.readableHash)"
    }
}
