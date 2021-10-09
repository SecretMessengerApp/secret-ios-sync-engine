//


import Foundation
import WireTransport
import WireRequestStrategy


private let log = ZMSLog(tag: "Network")


class UnauthenticatedOperationLoop: NSObject {

    let transportSession: UnauthenticatedTransportSessionProtocol
    let requestStrategies: [RequestStrategy]
    weak var operationQueue : ZMSGroupQueue?
    fileprivate var tornDown = false
    fileprivate var shouldEnqueue = true

    init(transportSession: UnauthenticatedTransportSessionProtocol, operationQueue: ZMSGroupQueue, requestStrategies: [RequestStrategy]) {
        self.transportSession = transportSession
        self.requestStrategies = requestStrategies
        self.operationQueue = operationQueue
        super.init()
        RequestAvailableNotification.addObserver(self)
    }
    
    deinit {
        precondition(tornDown, "Need to call tearDown before deinit")
    }
}

extension UnauthenticatedOperationLoop: TearDownCapable {
    func tearDown() {
        shouldEnqueue = false
        requestStrategies.forEach { ($0 as? TearDownCapable)?.tearDown() }
        transportSession.tearDown()
        tornDown = true
    }
}


extension UnauthenticatedOperationLoop: RequestAvailableObserver {

    func newRequestsAvailable() {
        var enqueueMore = true
        while enqueueMore && shouldEnqueue {
            let result = transportSession.enqueueRequest(withGenerator: generator)
            enqueueMore = result == .success
            switch result {
            case .maximumNumberOfRequests: log.debug("Maximum number of concurrent requests reached")
            case .nilRequest: log.debug("Nil request generated")
            default: break
            }
        }
    }
    
    func newMsgRequestsAvailable() {}
    
    func newExtensionSingleRequestsAvailable() {}
    
    func newExtensionStreamRequestsAvailable() {}
    
    private var generator: ZMTransportRequestGenerator {
        return { [weak self] in
            guard let `self` = self else { return nil }
            let request = (self.requestStrategies as NSArray).nextRequest()
            guard let queue = self.operationQueue else { return nil }
            request?.add(ZMCompletionHandler(on: queue) { [weak self] _ in
                self?.newRequestsAvailable()
            })
            return request
        }
    }

}
