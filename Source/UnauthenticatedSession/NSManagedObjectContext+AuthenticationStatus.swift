//

import Foundation

private let cookieLabelKey = "ZMCookieLabel"
private let registeredOnThisDeviceKey = "ZMRegisteredOnThisDevice"
private let registeredOnThisDeviceBeforeConversationInitializationKey = "ZMRegisteredOnThisDeviceBeforeConversationInitialization"


@objc extension NSManagedObjectContext {
    
    public var registeredOnThisDevice: Bool {
        get {
            return self.metadataBoolValueForKey(registeredOnThisDeviceKey)
        }
        set {
            self.setBooleanMetadataOnBothContexts(newValue, key: registeredOnThisDeviceKey)
        }
    }
    
    public var registeredOnThisDeviceBeforeConversationInitialization: Bool {
        get {
            return self.metadataBoolValueForKey(registeredOnThisDeviceBeforeConversationInitializationKey)
        }
        set {
            let value = NSNumber(booleanLiteral: newValue)
            self.setPersistentStoreMetadata(value, key: registeredOnThisDeviceBeforeConversationInitializationKey)
        }
    }
    
    private func metadataBoolValueForKey(_ key: String) -> Bool {
        return (self.persistentStoreMetadata(forKey: key) as? NSNumber)?.boolValue ?? false
    }
    
    private func setBooleanMetadataOnBothContexts(_ newValue: Bool, key: String) {
        precondition(!self.zm_isUserInterfaceContext)
        let value = NSNumber(booleanLiteral: newValue)
        self.setPersistentStoreMetadata(value, key: key)
        guard let uiContext = self.zm_userInterface else { return }
        uiContext.performGroupedBlock {
            uiContext.setPersistentStoreMetadata(value, key: key)
        }
    }
    
    public var legacyCookieLabel: String? {
        return self.persistentStoreMetadata(forKey: cookieLabelKey) as? String
    }
}
