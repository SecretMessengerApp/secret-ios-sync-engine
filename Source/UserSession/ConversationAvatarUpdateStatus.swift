

import Foundation

typealias ImageState = UserProfileImageUpdateStatus.ImageState
typealias ProfileUpdateState = UserProfileImageUpdateStatus.ProfileUpdateState

internal protocol ConversationAvatarUploadStatusProtocol: class {
    func hasAssetToDelete() -> Bool
    func consumeAssetToDelete() -> String?
    func consumeImage(for size: ProfileImageSize) -> Data?
    func hasImageToUpload(for size: ProfileImageSize) -> Bool
    func uploadingDone(imageSize: ProfileImageSize, assetId: String)
    func uploadingFailed(imageSize: ProfileImageSize, error: Error)
}

@objc public protocol ConversationAvatarUpdateProtocol: class {
    @objc(updateImageWithConversationID:ImageData:)
    func updateImage(with cid: String, imageData: Data)
}

internal protocol ConversationAvatarUploadStateChangeDelegate: class {
    func didTransition(from oldState: ProfileUpdateState, to currentState: ProfileUpdateState)
    func didTransition(from oldState: ImageState, to currentState: ImageState, for size: ProfileImageSize)
}

public final class ConversationAvatarUpdateStatus: NSObject {
    
    fileprivate var log = ZMSLog(tag: "ConversationAvatarUpdateStatus")
    
    internal var preprocessor: ZMAssetsPreprocessorProtocol?
    internal let queue: OperationQueue
    
    fileprivate let syncMOC: NSManagedObjectContext
    fileprivate let uiMOC: NSManagedObjectContext
    
    fileprivate var imageOwner: ImageOwner?
    fileprivate var imageState: [ProfileImageSize : UserProfileImageUpdateStatus.ImageState] {
        get {
            guard let cid = currentConversationID,
                let imageState = imageStateForConvs[cid] else { return [:] }
            return imageState
        }
        set {
            guard let cid = currentConversationID else { return }
            imageStateForConvs[cid] = newValue
        }
    }
    fileprivate var resizedImages: [ProfileImageSize : Data] {
        get {
            guard let cid = currentConversationID,
                let resizedImages = resizedImagesForConvs[cid] else { return [:] }
            return resizedImages
        }
        set {
            guard let cid = currentConversationID else { return }
            resizedImagesForConvs[cid] = newValue
        }
    }
    internal fileprivate(set) var state: ProfileUpdateState {
        get {
            guard let cid = currentConversationID,
                let state = stateForConvs[cid] else { return .ready }
            return state
        }
        set {
            guard let cid = currentConversationID else { return }
            stateForConvs[cid] = newValue
        }
    }
    
    private var currentConversationID: String? {
        return needProcessConversationIDs.first
    }
    fileprivate var needProcessConversationIDs = [String]() {
        didSet {
            
        }
    }
    fileprivate var needProcessDatas = [Data]()
    
    private var imageStateForConvs = [String: [ProfileImageSize : ImageState]]()
    private var resizedImagesForConvs = [String: [ProfileImageSize : Data]]()
    private var stateForConvs = [String: ProfileUpdateState]()
    
    internal fileprivate(set) var assetsToDelete = Set<String>()
    
    public convenience init(managedObjectContext: NSManagedObjectContext) {
        self.init(managedObjectContext: managedObjectContext, preprocessor: ZMAssetsPreprocessor(delegate: nil), queue: ZMImagePreprocessor.createSuitableImagePreprocessingQueue())
    }
    
    internal init(managedObjectContext: NSManagedObjectContext, preprocessor: ZMAssetsPreprocessorProtocol, queue: OperationQueue){
        log.debug("Created")
        self.queue = queue
        self.preprocessor = preprocessor
        self.syncMOC = managedObjectContext
        self.uiMOC = managedObjectContext.zm_userInterface
        super.init()
        self.preprocessor?.delegate = self
    }
    
}

// MARK: Main state transitions
extension ConversationAvatarUpdateStatus {
    
    
    private func removeCurrentTask() {
        if self.needProcessConversationIDs.count > 0 {
            self.needProcessConversationIDs.remove(at: 0)
            self.needProcessDatas.remove(at: 0)
            if self.needProcessConversationIDs.count > 0 {
                self.setState(state: .preprocess(image: self.needProcessDatas[0]))
            }
        }
    }
    
    internal func setState(state newState: ProfileUpdateState) {
        let currentState = self.state
        guard currentState.canTransition(to: newState) else {
            log.debug("Invalid transition: [\(currentState)] -> [\(newState)], ignoring")
            // Trying to transition to invalid state - ignore
            return
        }
        self.state = newState
        self.didTransition(from: currentState, to: newState)
    }
    
    private func didTransition(from oldState: ProfileUpdateState, to currentState: ProfileUpdateState) {
        log.debug("Transition: [\(oldState)] -> [\(currentState)]")
        switch (oldState, currentState) {
        case (_, .ready):
            resetImageState()
        case let (_, .preprocess(image: data)):
            startPreprocessing(imageData: data)
        case let (_, .update(previewAssetId: previewAssetId, completeAssetId: completeAssetId)):
            updateConversation(with:previewAssetId, completeAssetId: completeAssetId)
        case (_, .failed):
            resetImageState()
            setState(state: .ready)
            removeCurrentTask()
        }
    }
    
    private func updateConversation(with previewAssetId: String, completeAssetId: String) {
        
        guard let cid = self.currentConversationID,
            let uuid = UUID(uuidString: cid),
            let conversation = ZMConversation(remoteID: uuid, createIfNeeded: false, in: self.syncMOC) else {
                return
        }
        
        assetsToDelete.formUnion([conversation.groupImageSmallKey, conversation.groupImageMediumKey].compactMap { $0 })
       
        conversation.updateAndSyncProfileAssetIdentifiers(previewIdentifier: previewAssetId, completeIdentifier: completeAssetId)
        
        conversation.setImage(data: resizedImages[.preview], size: .preview)
        conversation.setImage(data: resizedImages[.complete], size: .complete)
        self.resetImageState()
        self.syncMOC.saveOrRollback()
        self.setState(state: .ready)
        removeCurrentTask()
    }
    
    private func startPreprocessing(imageData: Data) {
        ProfileImageSize.allSizes.forEach {
            setState(state: .preprocessing, for: $0)
        }
        
        let imageOwner = ConversationAvatarOwner(cid: self.currentConversationID!, imageData: imageData)
        guard let operations = preprocessor?.operations(forPreprocessingImageOwner: imageOwner), !operations.isEmpty else {
            resetImageState()
            setState(state: .failed(.preprocessingFailed))
            return
        }
        
        queue.addOperations(operations, waitUntilFinished: false)
    }
}

// MARK: Image state transitions
extension ConversationAvatarUpdateStatus {
    internal func imageState(for imageSize: ProfileImageSize) -> ImageState {
        return imageState[imageSize] ?? .ready
    }
    
    internal func setState(state newState: ImageState, for imageSize: ProfileImageSize) {
        let currentState = self.imageState(for: imageSize)
        guard currentState.canTransition(to: newState) else {
            // Trying to transition to invalid state - ignore
            return
        }
        
        self.imageState[imageSize] = newState
        self.didTransition(from: currentState, to: newState, for: imageSize)
    }
    
    internal func resetImageState() {
        imageState.removeAll()
        resizedImages.removeAll()
    }
    
    private func didTransition(from oldState: ImageState, to currentState: ImageState, for size: ProfileImageSize) {
        log.debug("Transition [\(size)]: [\(oldState)] -> [\(currentState)]")
        
        switch (oldState, currentState) {
        case let (_, .upload(image)):
            resizedImages[size] = image
            RequestAvailableNotification.notifyNewRequestsAvailable(self)
        case (_, .uploaded):
            // When one image is uploaded we check state of all other images
            let previewState = imageState(for: .preview)
            let completeState = imageState(for: .complete)
            
            switch (previewState, completeState) {
            case let (.uploaded(assetId: previewAssetId), .uploaded(assetId: completeAssetId)):
                // If both images are uploaded we can update profile
                setState(state: .update(previewAssetId: previewAssetId, completeAssetId: completeAssetId))
            default:
                break // Need to wait until both images are uploaded
            }
        case let (_, .failed(error)):
            setState(state: .failed(error))
        default:
            break
        }
    }
}

// Called from the UI to update a v3 image
extension ConversationAvatarUpdateStatus: ConversationAvatarUpdateProtocol {
    
    /// Starts the process of updating conversation picture.
    ///
    /// - Important: Expected to be run from UI thread
    ///
    /// - Parameter cid: conversationId that need to upload avatar
    /// - Parameter imageData: image data of the picture
    public func updateImage(with cid: String, imageData: Data) {
        syncMOC.performGroupedBlock {
            self.needProcessConversationIDs.append(cid)
            self.needProcessDatas.append(imageData)
            self.setState(state: .preprocess(image: imageData))
        }
    }
}

extension ConversationAvatarUpdateStatus: ZMAssetsPreprocessorDelegate {
    
    public func completedDownsampleOperation(_ operation: ZMImageDownsampleOperationProtocol, imageOwner: ZMImageOwner) {
        syncMOC.performGroupedBlock {
            ProfileImageSize.allSizes.forEach {
                if operation.format == $0.imageFormat {
                    self.setState(state: .upload(image: operation.downsampleImageData), for: $0)
                }
            }
        }
    }
    
    public func failedPreprocessingImageOwner(_ imageOwner: ZMImageOwner) {
        syncMOC.performGroupedBlock {
            self.setState(state: .failed(.preprocessingFailed))
        }
    }
    
    public func didCompleteProcessingImageOwner(_ imageOwner: ZMImageOwner) {}
    
    public func preprocessingCompleteOperation(for imageOwner: ZMImageOwner) -> Operation? {
        let dispatchGroup = syncMOC.dispatchGroup
        dispatchGroup?.enter()
        return BlockOperation() {
            dispatchGroup?.leave()
        }
    }
}

extension ConversationAvatarUpdateStatus: ConversationAvatarUploadStatusProtocol {
    
    /// Checks if there are assets that needs to be deleted
    ///
    /// - Returns: true if there are assets that needs to be deleted
    func hasAssetToDelete() -> Bool {
        return !assetsToDelete.isEmpty
    }
    
    /// Takes an asset ID that needs to be deleted and removes from the internal list
    ///
    /// - Returns: Asset ID or nil if nothing needs to be deleted
    internal func consumeAssetToDelete() -> String? {
        return assetsToDelete.removeFirst()
    }
    
    /// Checks if there is an image to upload
    ///
    /// - Important: should be called from sync thread
    /// - Parameter size: which image size to check
    /// - Returns: true if there is an image of this size ready for upload
    internal func hasImageToUpload(for size: ProfileImageSize) -> Bool {
        switch imageState(for: size) {
        case .upload:
            return true
        default:
            return false
        }
    }
    
    /// Takes an image that is ready for upload and marks it internally
    /// as currently being uploaded.
    ///
    /// - Parameter size: size of the image
    /// - Returns: Image data if there is image of this size ready for upload
    internal func consumeImage(for size: ProfileImageSize) -> Data? {
        switch imageState(for: size) {
        case .upload(image: let image):
            setState(state: .uploading, for: size)
            return image
        default:
            return nil
        }
    }
    
    /// Marks the image as uploaded successfully
    ///
    /// - Parameters:
    ///   - imageSize: size of the image
    ///   - assetId: resulting asset identifier after uploading it to the store
    internal func uploadingDone(imageSize: ProfileImageSize, assetId: String) {
        setState(state: .uploaded(assetId: assetId), for: imageSize)
    }
    
    /// Marks the image as failed to upload
    ///
    /// - Parameters:
    ///   - imageSize: size of the image
    ///   - error: transport error
    internal func uploadingFailed(imageSize: ProfileImageSize, error: Error) {
        setState(state: .failed(.uploadFailed(error)), for: imageSize)
    }
}

public final class ConversationAvatarOwner: NSObject, ZMImageOwner {
    
    static var imageFormats: [ZMImageFormat] {
        return [.medium, .profile]
    }
    
    let cid: String
    let imageData: Data
    
    init(cid: String, imageData: Data) {
        self.cid = cid
        self.imageData = imageData
        super.init()
    }
    
    public func requiredImageFormats() -> NSOrderedSet {
        return NSOrderedSet(array: ConversationAvatarOwner.imageFormats.map { $0.rawValue })
    }
    
    public func originalImageData() -> Data? {
        return imageData
    }
}
