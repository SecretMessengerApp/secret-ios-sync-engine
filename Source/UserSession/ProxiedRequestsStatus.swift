//


import Foundation


public typealias ProxyRequestCallback = (Data?, HTTPURLResponse?, NSError?) -> Void

@objc(ZMProxyRequest)
public class ProxyRequest : NSObject {
    @objc public let type: ProxiedRequestType
    @objc public let path: String
    @objc public let method : ZMTransportRequestMethod
    @objc public private(set) var callback : ProxyRequestCallback?
    
    @objc public init(type: ProxiedRequestType, path: String, method: ZMTransportRequestMethod, callback: ProxyRequestCallback?) {
        self.type = type
        self.path = path
        self.method = method
        self.callback = callback
    }
}


/// Keeps track of which requests to send to the backend
@objcMembers public final class ProxiedRequestsStatus: NSObject {
    
    public typealias Request = (type:ProxiedRequestType, path: String, method: ZMTransportRequestMethod, callback: ((Data?, HTTPURLResponse?, NSError?) -> Void)?)
    
    private let requestCancellation : ZMRequestCancellation

    /// List of requests to be sent to backend
    public var pendingRequests : Set<ProxyRequest> = Set()
    public var executedRequests : [ProxyRequest : ZMTaskIdentifier] = [:]
    
    public init(requestCancellation: ZMRequestCancellation) {
        self.requestCancellation = requestCancellation
    }
    
    @objc(addRequest:)
    public func add(request: ProxyRequest) {
        pendingRequests.insert(request)
    }
    
    @objc(cancelRequest:)
    public func cancel(request: ProxyRequest) {
        pendingRequests.remove(request)
        
        if let taskIdentifier = executedRequests.removeValue(forKey: request) {
            requestCancellation.cancelTask(with: taskIdentifier)
            
        }
    }
}
