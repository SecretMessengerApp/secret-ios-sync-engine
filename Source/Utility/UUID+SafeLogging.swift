////

import Foundation
import WireSystem
import WireUtilities

extension UUID: SafeForLoggingStringConvertible {
    public var safeForLoggingDescription: String {
        return transportString().readableHash
    }
}

