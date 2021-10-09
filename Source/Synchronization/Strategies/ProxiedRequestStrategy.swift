// 


import Foundation
import WireTransport


extension ProxiedRequestType {
    var basePath: String {
        switch self {
        case .giphy:
            return "/giphy"
        case .soundcloud:
            return "/soundcloud"
        case .youTube:
            return "/youtube"
        }
    }
}

/// Perform requests to the Giphy search API
@objc public final class ProxiedRequestStrategy : AbstractRequestStrategy {
    
    static fileprivate let BasePath = "/proxy"
    
    /// The requests to fulfill
    fileprivate weak var requestsStatus : ProxiedRequestsStatus?
    
    /// Requests fail after this interval if the network is unreachable
    fileprivate static let RequestExpirationTime : TimeInterval = 20
    
    @available (*, unavailable, message: "use `init(withManagedObjectContext:applicationStatus:requestsStatus:)` instead")
    override init(withManagedObjectContext moc: NSManagedObjectContext, applicationStatus: ApplicationStatus?) {
        fatalError()
    }
    
    public init(withManagedObjectContext moc: NSManagedObjectContext, applicationStatus: ApplicationStatus, requestsStatus: ProxiedRequestsStatus) {
        self.requestsStatus = requestsStatus
        super.init(withManagedObjectContext: moc, applicationStatus: applicationStatus)
    }
    
    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        guard let status = self.requestsStatus else { return nil }
        
        if let proxyRequest = status.pendingRequests.popFirst() {
            let fullPath = ProxiedRequestStrategy.BasePath + proxyRequest.type.basePath + proxyRequest.path
            let request = ZMTransportRequest(path: fullPath, method: proxyRequest.method, payload: nil)
            if proxyRequest.type == .soundcloud {
                request.doesNotFollowRedirects = true
            }
            request.expire(afterInterval: ProxiedRequestStrategy.RequestExpirationTime)
            request.add(ZMCompletionHandler(on: self.managedObjectContext.zm_userInterface, block: {
                response in
                    proxyRequest.callback?(response.rawData, response.rawResponse, response.transportSessionError as NSError?)
            }))
            request.add(ZMTaskCreatedHandler(on: self.managedObjectContext, block: { taskIdentifier in
                self.requestsStatus?.executedRequests[proxyRequest] = taskIdentifier
            }))
            
            return request
        }
        
        return nil
    }
    
}
