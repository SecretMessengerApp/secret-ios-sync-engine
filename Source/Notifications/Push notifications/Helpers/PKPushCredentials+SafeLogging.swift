////

import Foundation
import PushKit
import WireUtilities

extension PKPushCredentials: SafeForLoggingStringConvertible {
    public var safeForLoggingDescription: String {
        return "\(token.readableHash)"
    }
}
