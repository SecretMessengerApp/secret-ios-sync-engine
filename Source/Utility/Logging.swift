
import Foundation

struct Logging {
    static let eventProcessing = ZMSLog(tag: "event-processing")
    static let hugeEventProcessing = ZMSLog(tag: "huge-event-processing")
    static let network = ZMSLog(tag: "Network")
    static let push = ZMSLog(tag: "Push")
}
