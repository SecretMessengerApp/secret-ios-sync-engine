//

import Foundation

fileprivate extension AssetRequestFactory {
    static func request(for identifier: String, on queue: ZMSGroupQueue, block: @escaping ZMCompletionHandlerBlock) -> ZMTransportRequest {
        let request = ZMTransportRequest(path: "/assets/v3/\(identifier)", method: .methodDELETE, payload: nil)
        request.add(ZMCompletionHandler(on: queue, block: block))
        request.priorityLevel = .lowLevel
        return request
    }
}

final public class AssetDeletionRequestStrategy: AbstractRequestStrategy, ZMSingleRequestTranscoder {
    
    private var requestSync: ZMSingleRequestSync!
    private let identifierProvider: AssetDeletionIdentifierProviderType
    
    @objc(initWithManagedObjectContext:applicationStatus:identifierProvider:)
    required public init(context: NSManagedObjectContext, applicationStatus: ApplicationStatus, identifierProvider: AssetDeletionIdentifierProviderType) {
        self.identifierProvider = identifierProvider
        super.init(withManagedObjectContext: context, applicationStatus: applicationStatus)
        requestSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: context)
    }
    
    private func handle(response: ZMTransportResponse, for identifier: String) {
        switch response.result {
        case .success: identifierProvider.didDelete(identifier: identifier)
        case .permanentError: identifierProvider.didFailToDelete(identifier: identifier)
        default: break
        }
    }
    
    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        requestSync.readyForNextRequestIfNotBusy()
        return requestSync.nextRequest()
    }
    
    // MARK: - ZMSingleRequestTranscoder
    
    public func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        guard sync == requestSync, let identifier = identifierProvider.nextIdentifierToDelete() else { return nil }
        return AssetRequestFactory.request(for: identifier, on: managedObjectContext) { [weak self] response in
            self?.handle(response: response, for: identifier)
        }
    }
    
    public func didReceive(_ response: ZMTransportResponse, forSingleRequest sync: ZMSingleRequestSync) {
        // no-op
    }
}
