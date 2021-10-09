//

import Foundation

private let lastAccessTokenKey = "ZMLastAccessToken";
private let lastAccessTokenTypeKey = "ZMLastAccessTokenType";

@objc extension NSManagedObjectContext {
    
    public var accessToken : ZMAccessToken? {
        get {
            guard let token = self.persistentStoreMetadata(forKey: lastAccessTokenKey) as? String,
                let type = self.persistentStoreMetadata(forKey: lastAccessTokenTypeKey) as? String else {
                    return nil
            }
            return ZMAccessToken(token: token, type: type, expiresInSeconds: 0)
        }
        
        set {
            self.setPersistentStoreMetadata(newValue?.token, key: lastAccessTokenKey)
            self.setPersistentStoreMetadata(newValue?.type, key: lastAccessTokenTypeKey)
        }
    }
}
