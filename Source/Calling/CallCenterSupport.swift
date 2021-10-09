//

import Foundation

/// An opaque OTR calling message.
public typealias WireCallMessageToken = UnsafeMutableRawPointer

/**
 * The possible types of call.
 */

public enum AVSCallType: Int32 {
    case normal = 0
    case video = 1
    case audioOnly = 2
}

/**
 * Possible types of conversation in which calls can be initiated.
 */

public enum AVSConversationType: Int32 {
    case oneToOne = 0
    case group = 1
    case conference = 2
}

/**
 * An object that represents a calling event.
 */

public struct CallEvent {
    let data: Data
    let currentTimestamp: Date
    let serverTimestamp: Date
    let conversationId: UUID
    let userId: UUID
    let clientId: String
}

// MARK: - Call center transport

/// A block of code executed when the config request finishes.
public typealias CallConfigRequestCompletion = (String?, Int) -> Void

/**
 * An object that can perform requests on behalf of the call center.
 */

@objc public protocol WireCallCenterTransport: class {
    func send(data: Data, conversationId: UUID, userId: UUID, completionHandler: @escaping ((_ status: Int) -> Void))
    func requestCallConfig(completionHandler: @escaping CallConfigRequestCompletion)
}
