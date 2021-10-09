

import Foundation
import WireRequestStrategy


@objc public final class ConversationAvatarUpdateStrategy: AbstractRequestStrategy {
    internal let requestFactory = AssetRequestFactory()
    internal var upstreamRequestSyncs = [ProfileImageSize : ZMSingleRequestSync]()
    internal var deleteRequestSync: ZMSingleRequestSync?
    internal var downstreamRequestSyncs = [ProfileImageSize : ZMDownstreamObjectSyncWithWhitelist]()
    internal let moc: NSManagedObjectContext
    internal weak var imageUploadStatus: ConversationAvatarUploadStatusProtocol?
    
    fileprivate var observers: [Any] = []
    
    @objc public convenience init(managedObjectContext: NSManagedObjectContext, applicationStatusDirectory: ApplicationStatusDirectory) {
        self.init(managedObjectContext: managedObjectContext, applicationStatus: applicationStatusDirectory, imageUploadStatus: applicationStatusDirectory.converastionAvatarUpdateStatus)
    }
    
    internal init(managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus, imageUploadStatus: ConversationAvatarUploadStatusProtocol) {
        self.moc = managedObjectContext
        self.imageUploadStatus = imageUploadStatus
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        
        downstreamRequestSyncs[.preview] = whitelistConversationAvatarSync(for: .preview)
        downstreamRequestSyncs[.complete] = whitelistConversationAvatarSync(for: .complete)
        
        upstreamRequestSyncs[.preview] = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: moc)
        upstreamRequestSyncs[.complete] = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: moc)
        deleteRequestSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: moc)
        
        observers.append(NotificationInContext.addObserver(
            name: .conversationDidRequestPreviewAvatar,
            context: managedObjectContext.notificationContext,
            using: { [weak self] in self?.requestAvatarForNotification(note: $0) })
        )
        observers.append(NotificationInContext.addObserver(
            name: .conversationDidRequestCompleteAvatar,
            context: managedObjectContext.notificationContext,
            using: { [weak self] in self?.requestAvatarForNotification(note: $0) })
        )
    }
    
    fileprivate func whitelistConversationAvatarSync(for size: ProfileImageSize) -> ZMDownstreamObjectSyncWithWhitelist {
        let predicate: NSPredicate
        switch size {
        case .preview:
            predicate = ZMConversation.previewAvatarDownloadFilter
        case .complete:
            predicate = ZMConversation.completeAvatarDownloadFilter
        }
        
        return ZMDownstreamObjectSyncWithWhitelist(transcoder:self,
                                                   entityName:ZMConversation.entityName(),
                                                   predicateForObjectsToDownload:predicate,
                                                   managedObjectContext:moc)
    }
    
    internal func size(for requestSync: ZMDownstreamObjectSyncWithWhitelist) -> ProfileImageSize? {
        for (size, sync) in downstreamRequestSyncs {
            if sync === requestSync {
                return size
            }
        }
        return nil
    }
    
    internal func size(for requestSync: ZMSingleRequestSync) -> ProfileImageSize? {
        for (size, sync) in upstreamRequestSyncs {
            if sync === requestSync {
                return size
            }
        }
        return nil
    }
    
    func requestAvatarForNotification(note: NotificationInContext) {
        moc.performGroupedBlock {
            guard let objectID = note.object as? NSManagedObjectID,
                let object = self.moc.object(with: objectID) as? ZMManagedObject
                else { return }
            
            switch note.name {
            case .conversationDidRequestPreviewAvatar:
                self.downstreamRequestSyncs[.preview]?.whiteListObject(object)
            case .conversationDidRequestCompleteAvatar:
                self.downstreamRequestSyncs[.complete]?.whiteListObject(object)
            default:
                break
            }
            
            RequestAvailableNotification.notifyNewRequestsAvailable(nil)
        }
    }
    
    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        for size in ProfileImageSize.allSizes {
            let requestSync = downstreamRequestSyncs[size]
            if let request = requestSync?.nextRequest() {
                return request
            }
        }
        
        guard let updateStatus = imageUploadStatus else { return nil }
        
        // There are assets added for deletion
        if updateStatus.hasAssetToDelete() {
            deleteRequestSync?.readyForNextRequestIfNotBusy()
            return deleteRequestSync?.nextRequest()
        }
        
        let sync = ProfileImageSize.allSizes.filter(updateStatus.hasImageToUpload).compactMap { upstreamRequestSyncs[$0] }.first
        sync?.readyForNextRequestIfNotBusy()
        return sync?.nextRequest()
    }
}

extension ConversationAvatarUpdateStrategy: ZMDownstreamTranscoder {
    public func request(forFetching object: ZMManagedObject!, downstreamSync: ZMObjectSync!) -> ZMTransportRequest! {
        guard let whitelistSync = downstreamSync as? ZMDownstreamObjectSyncWithWhitelist else { return nil }
        guard let conversation = object as? ZMConversation else { return nil }
        guard let size = size(for: whitelistSync) else { return nil }
        
        let remoteId: String?
        switch size {
        case .preview:
            remoteId = conversation.groupImageSmallKey
        case .complete:
            remoteId = conversation.groupImageMediumKey
        }
        guard let assetId = remoteId else { return nil }
        let path = "/assets/v3/\(assetId)"
        let request = ZMTransportRequest.imageGet(fromPath: path)
        request.priorityLevel = .lowLevel
        return request
    }
    
    public func delete(_ object: ZMManagedObject!, with response: ZMTransportResponse!, downstreamSync: ZMObjectSync!) {
        guard let whitelistSync = downstreamSync as? ZMDownstreamObjectSyncWithWhitelist else { return }
        guard let conversation = object as? ZMConversation else { return }
        
        switch size(for: whitelistSync) {
        case .preview?: conversation.groupImageSmallKey = nil
        case .complete?: conversation.groupImageMediumKey = nil
        default: break
        }
    }
    
    public func update(_ object: ZMManagedObject!, with response: ZMTransportResponse!, downstreamSync: ZMObjectSync!) {
        guard let whitelistSync = downstreamSync as? ZMDownstreamObjectSyncWithWhitelist else { return }
        guard let conversation = object as? ZMConversation else { return }
        guard let size = size(for: whitelistSync) else { return }
        
        conversation.setImage(data: response.rawData, size: size)
    }
}

extension ConversationAvatarUpdateStrategy: ZMContextChangeTrackerSource {
    public var contextChangeTrackers: [ZMContextChangeTracker] {
        return Array(downstreamRequestSyncs.values)
    }
}

extension ConversationAvatarUpdateStrategy: ZMSingleRequestTranscoder {
    public func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        if let size = size(for: sync), let image = imageUploadStatus?.consumeImage(for: size) {
            let request = requestFactory.upstreamRequestForAsset(withData: image, shareable: true, retention: .eternal)
            request?.addContentDebugInformation("Uploading to /assets/V3: [\(size)]  [\(image)] ")
            request?.priorityLevel = .highLevel
            return request
        } else if sync === deleteRequestSync {
            if let assetId = imageUploadStatus?.consumeAssetToDelete() {
                let path = "/assets/v3/\(assetId)"
                let request = ZMTransportRequest(path: path, method: .methodDELETE, payload: nil)
                request.priorityLevel = .lowLevel
            }
        }
        return nil
    }
    
    public func didReceive(_ response: ZMTransportResponse, forSingleRequest sync: ZMSingleRequestSync) {
        guard let size = size(for: sync) else { return }
        guard response.result == .success else {
            let error = AssetTransportError(response: response)
            imageUploadStatus?.uploadingFailed(imageSize: size, error: error)
            return
        }
        guard let payload = response.payload?.asDictionary(), let assetId = payload["key"] as? String else { fatal("No asset ID present in payload") }
        imageUploadStatus?.uploadingDone(imageSize: size, assetId: assetId)
    }
}
