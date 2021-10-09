// 


import UIKit
import WireTransport
import WireUtilities


public struct SignalingKeys {
    let verificationKey : Data
    let decryptionKey : Data
    
    init(verificationKey: Data? = nil, decryptionKey: Data? = nil) {
        self.verificationKey = verificationKey ?? NSData.secureRandomData(ofLength: APSSignalingKeysStore.defaultKeyLengthBytes)
        self.decryptionKey = decryptionKey ?? NSData.secureRandomData(ofLength: APSSignalingKeysStore.defaultKeyLengthBytes)
    }
}


@objcMembers
public final class APSSignalingKeysStore: NSObject {
    public var apsDecoder: ZMAPSMessageDecoder!
    internal var verificationKey : Data!
    internal var decryptionKey : Data!

    internal static let verificationKeyAccountName = "APSVerificationKey"
    internal static let decryptionKeyAccountName = "APSDecryptionKey"
    internal static let defaultKeyLengthBytes : UInt = 256 / 8
    
    public init?(userClient: UserClient) {
        super.init()
        if let verificationKey = userClient.apsVerificationKey, let decryptionKey = userClient.apsDecryptionKey {
            self.verificationKey = verificationKey
            self.decryptionKey = decryptionKey
            self.apsDecoder = ZMAPSMessageDecoder(encryptionKey: decryptionKey, macKey: verificationKey)
        }
        else {
            return nil
        }
    }
    
    /// use this method to create new keys, e.g. for client registration or update
    static func createKeys() -> SignalingKeys {
        return SignalingKeys()
    }
    
    /// we previously stored keys in the key chain. use this method to retreive the previously stored values to move them into the selfClient
    static func keysStoredInKeyChain() -> SignalingKeys? {
        guard let verificationKey = ZMKeychain.data(forAccount: self.verificationKeyAccountName),
              let decryptionKey = ZMKeychain.data(forAccount: self.decryptionKeyAccountName)
        else { return nil }
        
        return SignalingKeys(verificationKey: verificationKey, decryptionKey: decryptionKey)
    }
    
    static func clearSignalingKeysInKeyChain(){
        ZMKeychain.deleteAllKeychainItems(withAccountName: self.verificationKeyAccountName)
        ZMKeychain.deleteAllKeychainItems(withAccountName: self.decryptionKeyAccountName)
    }
    
    public func decryptDataDictionary(_ payload: [AnyHashable : Any]!) -> [AnyHashable : Any]! {
        return self.apsDecoder.decodeAPSPayload(payload)
    }
}

