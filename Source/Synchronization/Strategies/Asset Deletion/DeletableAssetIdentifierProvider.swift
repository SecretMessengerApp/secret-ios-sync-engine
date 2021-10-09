//

@objc public protocol DeletableAssetIdentifierProvider: class {
    var assetIdentifiersToBeDeleted: Set<String> { get set }
}

extension NSManagedObjectContext: DeletableAssetIdentifierProvider {
    
    private static let assetIdentifiersToBeDeletedKey = "assetIdentifiersToBeDeleted"
    
    public var assetIdentifiersToBeDeleted: Set<String> {
        set {
            setPersistentStoreMetadata(Array(newValue), key: NSManagedObjectContext.assetIdentifiersToBeDeletedKey)
        }
        get {
            return Set(persistentStoreMetadata(forKey: NSManagedObjectContext.assetIdentifiersToBeDeletedKey) as? [String] ?? [])
        }
    }
}
