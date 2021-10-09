//

import Foundation

public typealias BackgroundFetchHandler = (_ fetchResult: UIBackgroundFetchResult) -> Void

public typealias BackgroundTaskHandler = (_ taskResult: BackgroundTaskResult) -> Void

private let zmLog = ZMSLog(tag: "OperationStatus")

@objc(ZMOperationStatusDelegate)
public protocol OperationStatusDelegate : class {
    
    @objc(operationStatusDidChangeState:)
    func operationStatus(didChangeState state: SyncEngineOperationState)
}


@objc(ZMBackgroundTaskResult)
public enum BackgroundTaskResult : UInt {
    case finished
    case failed
}

@objc public enum SyncEngineOperationState : UInt, CustomStringConvertible {
    case background
    case backgroundCall
    case backgroundFetch
    case backgroundTask
    case foreground
    
    public var description : String {
        switch self {
        case .background:
            return "background"
        case .backgroundCall:
            return "backgroundCall"
        case .backgroundFetch:
            return "backgroundFetch"
        case .backgroundTask:
            return "backgroundTask"
        case .foreground:
            return "foreground"
        }
    }
}

@objcMembers
public class OperationStatus : NSObject {
        
    public weak var delegate : OperationStatusDelegate?
    
    private var backgroundFetchTimer : Timer?
    private var backgroundTaskTimer : Timer?

    private var backgroundFetchHandler : BackgroundFetchHandler? {
        didSet {
            updateOperationState()
        }
    }
    
    private var backgroundTaskHandler : BackgroundTaskHandler? {
        didSet {
            updateOperationState()
        }
    }
    
    public var isInBackground = true {
        didSet {
            updateOperationState()
        }
    }
    
    public var hasOngoingCall = false {
        didSet {
            updateOperationState()
        }
    }
    
    public private(set) var operationState : SyncEngineOperationState = .background {
        didSet {
            delegate?.operationStatus(didChangeState: operationState)
        }
    }
    
    public func startBackgroundFetch(withCompletionHandler completionHandler: @escaping BackgroundFetchHandler) {
        startBackgroundFetch(timeout: 30.0, withCompletionHandler: completionHandler)
    }
    
    public func startBackgroundFetch(timeout: TimeInterval, withCompletionHandler completionHandler: @escaping BackgroundFetchHandler) {
        guard backgroundFetchHandler == nil else {
            return completionHandler(.failed)
        }
        
        backgroundFetchHandler = completionHandler
        backgroundFetchTimer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(backgroundFetchTimeout), userInfo: nil, repeats: false)
        RequestAvailableNotification.notifyNewRequestsAvailable(self)
    }
    
    public func startBackgroundTask(withCompletionHandler completionHandler: @escaping BackgroundTaskHandler) {
        startBackgroundTask(timeout: 30.0, withCompletionHandler: completionHandler)
    }
    
    public func startBackgroundTask(timeout: TimeInterval, withCompletionHandler completionHandler: @escaping BackgroundTaskHandler) {
        guard backgroundTaskHandler == nil, isInBackground else {
            return completionHandler(.failed)
        }
        
        backgroundTaskHandler = completionHandler
        backgroundTaskTimer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(backgroundTaskTimeout), userInfo: nil, repeats: false)
    }
    
    @objc func backgroundFetchTimeout() {
        finishBackgroundFetch(withFetchResult: .failed)
    }
    
    @objc func backgroundTaskTimeout() {
        finishBackgroundTask(withTaskResult: .failed)
    }
    
    public func finishBackgroundFetch(withFetchResult result: UIBackgroundFetchResult) {
        backgroundFetchTimer?.invalidate()
        backgroundFetchTimer = nil
        DispatchQueue.main.async {
            self.backgroundFetchHandler?(result)
            self.backgroundFetchHandler = nil
        }
    }
    
    public func finishBackgroundTask(withTaskResult result: BackgroundTaskResult) {
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil
        DispatchQueue.main.async {
            self.backgroundTaskHandler?(result)
            self.backgroundTaskHandler = nil
        }
    }
    
    fileprivate func updateOperationState() {
        let oldOperationState = operationState
        let newOperationState = calculatedOperationState
        
        if newOperationState != oldOperationState {
            zmLog.debug("operation state changed from \(oldOperationState) to \(newOperationState)")
            operationState = newOperationState
        }
    }
    
    fileprivate var calculatedOperationState : SyncEngineOperationState {
        if (isInBackground) {
            if hasOngoingCall {
                return .backgroundCall
            }
            
            if backgroundFetchHandler != nil {
                return .backgroundFetch
            }
            
            if backgroundTaskHandler != nil {
                return .backgroundTask
            }
            
            return .background
        } else {
            return .foreground
        }
    }
    
}
