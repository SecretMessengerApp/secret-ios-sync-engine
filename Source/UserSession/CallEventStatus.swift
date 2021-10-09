//

import Foundation

private let zmLog = ZMSLog(tag: "calling")

/// CallEventStatus keep track of call events which are waiting to be processed. this is important to know when
/// the app is launched via push notification since then we need keep the app running until we've processed all
/// call events.
@objcMembers
public class CallEventStatus: NSObject, ZMTimerClient {
        
    var eventProcessingTimoutInterval: TimeInterval = 2
    
    fileprivate var observers: [() -> Void] = []
    fileprivate var eventProcessingTimer: ZMTimer? = nil
    
    fileprivate var callEventsWaitingToBeProcessed: Int = 0 {
        didSet {
            if callEventsWaitingToBeProcessed == 0 {
                zmLog.debug("CallEventStatus: all events processed, starting timer")
                eventProcessingTimer = ZMTimer.init(target: self, operationQueue: .main)
                eventProcessingTimer?.fire(afterTimeInterval: eventProcessingTimoutInterval)
            }
        }
    }
    
    public func timerDidFire(_ timer: ZMTimer!) {
        zmLog.debug("CallEventStatus: finished timer")
        observers.forEach({ $0() })
        observers = []
        eventProcessingTimer = nil
    }
    
    deinit {
        eventProcessingTimer = nil
    }
    
    /// Wait for all calling events to be processed and then calls the completion handler.
    ///
    /// NOTE it is not guranteed that completion handler is called on the same thread as the caller.
    ///
    /// Returns: true if there's was any unprocessed calling events.
    @discardableResult
    public func waitForCallEventProcessingToComplete(_ completionHandler: @escaping () -> Void) -> Bool {
        guard callEventsWaitingToBeProcessed != 0 || eventProcessingTimer != nil else {
            zmLog.debug("CallEventStatus: No active call events, completing")
            completionHandler()
            return false
        }
        zmLog.debug("CallEventStatus: Active call events, waiting")
        observers.append(completionHandler)
        return true
    }
    
    public func scheduledCallEventForProcessing() {
        callEventsWaitingToBeProcessed += 1
    }
    
    public func finishedProcessingCallEvent() {
        callEventsWaitingToBeProcessed -= 1
    }
    
}
