//

import Foundation

private let log = ZMSLog(tag: "AssetDeletion")

@objc public protocol AssetDeletionIdentifierProviderType: class {
    func nextIdentifierToDelete() -> String?
    func didDelete(identifier: String)
    func didFailToDelete(identifier: String)
}

final public class AssetDeletionStatus: NSObject, AssetDeletionIdentifierProviderType {
    
    private var provider: DeletableAssetIdentifierProvider
    private var identifiersInProgress = Set<String>()
    private let queue: ZMSGroupQueue
    
    private var remainingIdentifiersToDelete: Set<String> {
        return provider.assetIdentifiersToBeDeleted.subtracting(identifiersInProgress)
    }
    
    @objc(initWithProvider:queue:)
    public init(provider: DeletableAssetIdentifierProvider, queue: ZMSGroupQueue) {
        self.queue = queue
        self.provider = provider
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handle), name: .deleteAssetNotification, object: nil)
    }
    
    @objc private func handle(note: Notification) {
        guard note.name == Notification.Name.deleteAssetNotification, let identifier = note.object as? String else { return }
        queue.performGroupedBlock { [weak self] in
            self?.add(identifier)
        }
    }
    
    private func add(_ identifier: String) {
        provider.assetIdentifiersToBeDeleted.insert(identifier)
        RequestAvailableNotification.notifyNewRequestsAvailable(nil)
        log.debug("Added asset identifier to list: \(identifier)")
    }
    
    private func remove(_ identifier: String) {
        identifiersInProgress.remove(identifier)
        provider.assetIdentifiersToBeDeleted.remove(identifier)
    }
    
    // MARK: - AssetDeletionIdentifierProviderType
    
    public func nextIdentifierToDelete() -> String? {
        guard let first = remainingIdentifiersToDelete.first else { return nil }
        identifiersInProgress.insert(first)
        return first
    }
    
    public func didDelete(identifier: String) {
        remove(identifier)
        log.debug("Successfully deleted identifier: \(identifier)")
    }
    
    public func didFailToDelete(identifier: String) {
        remove(identifier)
        log.debug("Failed to delete identifier: \(identifier)")
    }
}
