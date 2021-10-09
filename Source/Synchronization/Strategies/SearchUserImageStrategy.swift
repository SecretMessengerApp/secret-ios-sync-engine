//


fileprivate let userPath = "/users?ids="

public class SearchUserImageStrategy : AbstractRequestStrategy {

    fileprivate unowned var uiContext: NSManagedObjectContext
    fileprivate unowned var syncContext: NSManagedObjectContext
    
    fileprivate var requestedMissingFullProfiles: Set<UUID> = Set()
    fileprivate var requestedMissingFullProfilesInProgress: Set<UUID> = Set()
    
    fileprivate var requestedPreviewAssets: [UUID : SearchUserAssetKeys?] = [:]
    fileprivate var requestedCompleteAssets: [UUID : SearchUserAssetKeys?] = [:]
    fileprivate var requestedPreviewAssetsInProgress: Set<UUID> = Set()
    fileprivate var requestedCompleteAssetsInProgress: Set<UUID> = Set()
    
    
    fileprivate var observers: [Any] = []
    
    @available (*, unavailable)
    public override init(withManagedObjectContext moc: NSManagedObjectContext, applicationStatus: ApplicationStatus?) {
        fatalError()
    }
    
    public init(applicationStatus: ApplicationStatus, managedObjectContext: NSManagedObjectContext) {
        
        self.syncContext = managedObjectContext
        self.uiContext = managedObjectContext.zm_userInterface
        
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        
        observers.append(NotificationInContext.addObserver(
            name: .searchUserDidRequestPreviewAsset,
            context: managedObjectContext.notificationContext,
            using: { [weak self] in
                self?.requestAsset(with: $0)
            })
        )
        
        observers.append(NotificationInContext.addObserver(
            name: .searchUserDidRequestCompleteAsset,
            context: managedObjectContext.notificationContext,
            using: { [weak self] in
                self?.requestAsset(with: $0)
            })
        )
    }
    
    public func requestAsset(with note: NotificationInContext) {
        guard let searchUser = note.object as? ZMSearchUser, let userId = searchUser.remoteIdentifier  else { return }
        
        if !searchUser.hasDownloadedFullUserProfile {
            requestedMissingFullProfiles.insert(userId)
        }
                
        switch note.name {
        case .searchUserDidRequestPreviewAsset:
            requestedPreviewAssets[userId] = searchUser.assetKeys
        case .searchUserDidRequestCompleteAsset:
            requestedCompleteAssets[userId] = searchUser.assetKeys
        default:
            break
        }
        
        RequestAvailableNotification.notifyNewRequestsAvailable(nil)
    }
    
    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        let request = fetchUserProfilesRequest() ?? fetchAssetRequest()
        request?.setDebugInformationTranscoder(self)
        return request
    }
    
    func fetchAssetRequest() -> ZMTransportRequest? {
        let previewAssetRequestA = requestedPreviewAssets.lazy.filter({ !self.requestedPreviewAssetsInProgress.contains($0.key) && $0.value != nil }).first
        let completeAssetRequestA = requestedCompleteAssets.lazy.filter({ !self.requestedCompleteAssetsInProgress.contains($0.key) && $0.value != nil}).first
        
        if let previewAssetRequest = previewAssetRequestA, let assetKeys = previewAssetRequest.value, let request = request(for: assetKeys, size: .preview, user: previewAssetRequest.key) {
            requestedPreviewAssetsInProgress.insert(previewAssetRequest.key)
            
            request.add(ZMCompletionHandler(on: syncContext, block: { [weak self] (response) in
                self?.processAsset(response: response, for: previewAssetRequest.key, size: .preview)
            }))
            
            return request
        }
        
        if let completeAssetRequest = completeAssetRequestA, let assetKeys = completeAssetRequest.value, let request = request(for: assetKeys, size: .complete, user: completeAssetRequest.key) {
            requestedCompleteAssetsInProgress.insert(completeAssetRequest.key)
            
            request.add(ZMCompletionHandler(on: syncContext, block: { [weak self] (response) in
                self?.processAsset(response: response, for: completeAssetRequest.key, size: .complete)
            }))
            
            return request
        }
        
        return nil
    }
    
    func request(for assetKeys: SearchUserAssetKeys, size: ProfileImageSize, user: UUID) -> ZMTransportRequest? {
        if let key = size == .preview ? assetKeys.preview : assetKeys.complete {
            return ZMTransportRequest(getFromPath: "/assets/v3/\(key)")
        }
        return nil
    }
    
    func processAsset(response: ZMTransportResponse, for user: UUID, size: ProfileImageSize) {
        
        let tryAgain = response.result != .permanentError && response.result != .success
        
        switch size {
        case .preview:
            if !tryAgain {
                requestedPreviewAssets.removeValue(forKey: user)
            }
            requestedPreviewAssetsInProgress.remove(user)
        case .complete:
            if !tryAgain {
                requestedCompleteAssets.removeValue(forKey: user)
            }
            requestedCompleteAssetsInProgress.remove(user)
        }
        
        uiContext.performGroupedBlock {
            guard let searchUser = self.uiContext.zm_searchUserCache?.object(forKey: user as NSUUID) else { return }
            
            if response.result == .success {
                if let imageData = response.imageData ?? response.rawData {
                    searchUser.updateImageData(for: size, imageData: imageData)
                }
            } else if response.result == .permanentError {
                searchUser.reportImageDataHasBeenDeleted()
            }
        }
    }
    
    func fetchUserProfilesRequest() -> ZMTransportRequest? {
        let missingFullProfiles = requestedMissingFullProfiles.subtracting(requestedMissingFullProfilesInProgress)
        
        guard missingFullProfiles.count > 0 else { return nil }
        
        requestedMissingFullProfilesInProgress.formUnion(missingFullProfiles)
        
        return SearchUserImageStrategy.requestForFetchingFullProfile(for: missingFullProfiles, completionHandler: ZMCompletionHandler(on: managedObjectContext, block: { (response) in
            
            self.requestedMissingFullProfilesInProgress.subtract(missingFullProfiles)
            
            // On temporary errors we keep requestedMissingFullProfiles so that we'll retry the request
            if response.result == .success || response.result == .permanentError {
                self.requestedMissingFullProfiles.subtract(missingFullProfiles)
            }

            guard response.result == .success else { return }
            
            self.uiContext.performGroupedBlock {
                guard let userProfilePayloads = response.payload as? [[String : Any]] else { return }
                
                for userProfilePayload in userProfilePayloads {
                    guard let userId = (userProfilePayload["id"] as? String).flatMap(UUID.init),
                          let searchUser = self.uiContext.zm_searchUserCache?.object(forKey: userId as NSUUID) else { continue }
                    
                    searchUser.update(from: userProfilePayload)
                    
                    if let assetKeys = searchUser.assetKeys {
                        self.updateAssetKeys(assetKeys, for: userId)
                    }
                }
            }
        }))
    }
    
    func updateAssetKeys(_ assetKeys: SearchUserAssetKeys, for userId: UUID) {
        syncContext.performGroupedBlock {
            if self.requestedPreviewAssets.keys.contains(userId) {
                self.requestedPreviewAssets[userId] = assetKeys
            }
            
            if self.requestedCompleteAssets.keys.contains(userId) {
                self.requestedCompleteAssets[userId] = assetKeys
            }
            
            RequestAvailableNotification.notifyNewRequestsAvailable(nil)
        }
    }
    
    public static func requestForFetchingFullProfile(for usersWithIDs: Set<UUID>, completionHandler:ZMCompletionHandler) -> ZMTransportRequest {
        let usersList = usersWithIDs.map{$0.transportString()}.joined(separator: ",")
        let request = ZMTransportRequest(getFromPath: userPath + usersList)
        request.add(completionHandler)
        return request;
    }

}
