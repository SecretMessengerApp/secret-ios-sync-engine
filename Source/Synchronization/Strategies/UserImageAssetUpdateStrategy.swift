//

import Foundation
import WireRequestStrategy

internal enum AssetTransportError: Error {
    case invalidLength
    case assetTooLarge
    case other(Error?)
    
    init(response: ZMTransportResponse) {
        switch (response.httpStatus, response.payloadLabel()) {
        case (400, .some("invalid-length")):
            self = .invalidLength
        case (413, .some("client-error")):
            self = .assetTooLarge
        default:
            self = .other(response.transportSessionError)
        }
    }
}

@objc public final class UserImageAssetUpdateStrategy: AbstractRequestStrategy {
    internal let requestFactory = AssetRequestFactory()
    internal var upstreamRequestSyncs = [ProfileImageSize : ZMSingleRequestSync]()
    internal var deleteRequestSync: ZMSingleRequestSync?
    internal var downstreamRequestSyncs = [ProfileImageSize : ZMDownstreamObjectSyncWithWhitelist]()
    internal let moc: NSManagedObjectContext
    internal weak var imageUploadStatus: UserProfileImageUploadStatusProtocol?
    
    fileprivate var observers: [Any] = []
    
    @objc public convenience init(managedObjectContext: NSManagedObjectContext, applicationStatusDirectory: ApplicationStatusDirectory) {
        self.init(managedObjectContext: managedObjectContext, applicationStatus: applicationStatusDirectory, imageUploadStatus: applicationStatusDirectory.userProfileImageUpdateStatus)
    }

    internal init(managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus, imageUploadStatus: UserProfileImageUploadStatusProtocol) {
        self.moc = managedObjectContext
        self.imageUploadStatus = imageUploadStatus
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        
        downstreamRequestSyncs[.preview] = whitelistUserImageSync(for: .preview)
        downstreamRequestSyncs[.complete] = whitelistUserImageSync(for: .complete)
        downstreamRequestSyncs.forEach { (_, sync) in
            sync.whiteListObject(ZMUser.selfUser(in: managedObjectContext))
        }
        
        upstreamRequestSyncs[.preview] = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: moc)
        upstreamRequestSyncs[.complete] = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: moc)
        deleteRequestSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: moc)
        
        observers.append(NotificationInContext.addObserver(
            name: .userDidRequestCompleteAsset,
            context: managedObjectContext.notificationContext,
            using: { [weak self] in self?.requestAssetForNotification(note: $0) })
        )
        observers.append(NotificationInContext.addObserver(
            name: .userDidRequestPreviewAsset,
            context: managedObjectContext.notificationContext,
            using: { [weak self] in self?.requestAssetForNotification(note: $0) })
        )
    }
    
    fileprivate func whitelistUserImageSync(for size: ProfileImageSize) -> ZMDownstreamObjectSyncWithWhitelist {
        let predicate: NSPredicate
        switch size {
        case .preview:
            predicate = ZMUser.previewImageDownloadFilter
        case .complete:
            predicate = ZMUser.completeImageDownloadFilter
        }
        
        return ZMDownstreamObjectSyncWithWhitelist(transcoder:self,
                                            entityName:ZMUser.entityName(),
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
    
    func requestAssetForNotification(note: NotificationInContext) {
        moc.performGroupedBlock {
            guard let objectID = note.object as? NSManagedObjectID,
                let object = self.moc.object(with: objectID) as? ZMManagedObject
                else { return }
            
            switch note.name {
            case .userDidRequestPreviewAsset:
                self.downstreamRequestSyncs[.preview]?.whiteListObject(object)
            case .userDidRequestCompleteAsset:
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

extension UserImageAssetUpdateStrategy: ZMDownstreamTranscoder {
    public func request(forFetching object: ZMManagedObject!, downstreamSync: ZMObjectSync!) -> ZMTransportRequest! {
        guard let whitelistSync = downstreamSync as? ZMDownstreamObjectSyncWithWhitelist else { return nil }
        guard let user = object as? ZMUser else { return nil }
        guard let size = size(for: whitelistSync) else { return nil }

        let remoteId: String?
        switch size {
        case .preview:
            remoteId = user.previewProfileAssetIdentifier
        case .complete:
            remoteId = user.completeProfileAssetIdentifier
        }
        guard let assetId = remoteId else { return nil }
        let path = "/assets/v3/\(assetId)"
        let request = ZMTransportRequest.imageGet(fromPath: path)
        request.priorityLevel = .lowLevel
        return request
    }
    
    public func delete(_ object: ZMManagedObject!, with response: ZMTransportResponse!, downstreamSync: ZMObjectSync!) {
        guard let whitelistSync = downstreamSync as? ZMDownstreamObjectSyncWithWhitelist else { return }
        guard let user = object as? ZMUser else { return }

        switch size(for: whitelistSync) {
        case .preview?: user.previewProfileAssetIdentifier = nil
        case .complete?: user.completeProfileAssetIdentifier = nil
        default: break
        }
    }

    public func update(_ object: ZMManagedObject!, with response: ZMTransportResponse!, downstreamSync: ZMObjectSync!) {
        guard let whitelistSync = downstreamSync as? ZMDownstreamObjectSyncWithWhitelist else { return }
        guard let user = object as? ZMUser else { return }
        guard let size = size(for: whitelistSync) else { return }
        
        user.setImage(data: response.rawData, size: size)
    }
}

extension UserImageAssetUpdateStrategy: ZMContextChangeTrackerSource {
    public var contextChangeTrackers: [ZMContextChangeTracker] {
        return Array(downstreamRequestSyncs.values)
    }
}

extension UserImageAssetUpdateStrategy: ZMSingleRequestTranscoder {
    public func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        if let size = size(for: sync), let image = imageUploadStatus?.consumeImage(for: size) {
            let request = requestFactory.upstreamRequestForAsset(withData: image, shareable: true, retention: .eternal)
            request?.addContentDebugInformation("Uploading to /assets/V3: [\(size)]  [\(image)] ")
            return request
        } else if sync === deleteRequestSync {
            if let assetId = imageUploadStatus?.consumeAssetToDelete() {
                let path = "/assets/v3/\(assetId)"
                return ZMTransportRequest(path: path, method: .methodDELETE, payload: nil)
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

