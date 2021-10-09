//

import Foundation
import avs

/**
 * Reasons why a call can be terminated.
 */

public enum CallClosedReason : Int32 {

    /// Ongoing call was closed by remote or self user
    case normal
    /// Incoming call was canceled by remote
    case canceled
    /// Incoming call was answered on another device
    case anweredElsewhere
    /// Incoming call was rejected on another device
    case rejectedElsewhere
    /// Outgoing call timed out
    case timeout
    /// Ongoing call lost media and was closed
    case lostMedia
    /// Call was closed because of internal error in AVS
    case internalError
    /// Call was closed due to a input/output error (couldn't access microphone)
    case inputOutputError
    /// Call left by the selfUser but continues until everyone else leaves or AVS closes it
    case stillOngoing
    /// Call was dropped due to the security level degrading
    case securityDegraded
    /// Call was closed for an unknown reason. This is most likely a bug.
    case unknown

    // MARK: - Briding

    /**
     * Creates the call closed reason from the AVS flag.
     * - parameter wcall_reason: The flag
     * - returns: The decoded reason, or `.unknown` if the flag couldn't be processed.
     */

    init(wcall_reason: Int32) {
        switch wcall_reason {
        case WCALL_REASON_NORMAL:
            self = .normal
        case WCALL_REASON_CANCELED:
            self = .canceled
        case WCALL_REASON_ANSWERED_ELSEWHERE:
            self = .anweredElsewhere
        case WCALL_REASON_REJECTED:
            self = .rejectedElsewhere
        case WCALL_REASON_TIMEOUT:
            self = .timeout
        case WCALL_REASON_TIMEOUT_ECONN:
            self = .timeout
        case WCALL_REASON_LOST_MEDIA:
            self = .lostMedia
        case WCALL_REASON_ERROR:
            self = .internalError
        case WCALL_REASON_IO_ERROR:
            self = .inputOutputError
        case WCALL_REASON_STILL_ONGOING:
            self = .stillOngoing
        default:
            self = .unknown
        }
    }

    /// The raw flag for the call end.
    var wcall_reason : Int32 {
        switch self {
        case .normal:
            return WCALL_REASON_NORMAL
        case .canceled:
            return WCALL_REASON_CANCELED
        case .anweredElsewhere:
            return WCALL_REASON_ANSWERED_ELSEWHERE
        case .rejectedElsewhere:
            return WCALL_REASON_REJECTED
        case .timeout:
            return WCALL_REASON_TIMEOUT
        case .lostMedia:
            return WCALL_REASON_LOST_MEDIA
        case .internalError:
            return WCALL_REASON_ERROR
        case .inputOutputError:
            return WCALL_REASON_IO_ERROR
        case .stillOngoing:
            return WCALL_REASON_STILL_ONGOING
        case .securityDegraded:
            return WCALL_REASON_ERROR
        case .unknown:
            return WCALL_REASON_ERROR
        }
    }
}
