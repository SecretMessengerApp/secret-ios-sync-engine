//

import Foundation
import avs

/**
 * General error codes for calls
 */
let WCALL_ERROR_UNKNOWN_PROTOCOL: Int32 = 1000

public enum CallError : Int32 {
    
    /// Impossible to receive a call due to incompatible protocol (e.g. older versions)
    case unknownProtocol
    
    /**
     * Creates the call error from the AVS flag.
     * - parameter wcall_error: The flag
     * - returns: The decoded error, or `nil` if the flag couldn't be processed.
     */
    
    init?(wcall_error: Int32) {
        switch wcall_error {
        case WCALL_ERROR_UNKNOWN_PROTOCOL:
            self = .unknownProtocol
        default:
            return nil
        }
    }
    
    /// The raw flag for the call error
    var wcall_error : Int32 {
        switch self {
        case .unknownProtocol:
            return WCALL_REASON_NORMAL
        }
    }
}
