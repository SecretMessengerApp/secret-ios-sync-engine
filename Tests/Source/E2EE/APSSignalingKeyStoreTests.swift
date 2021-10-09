//


import XCTest
@testable import WireSyncEngine
import WireTesting
import WireTransport

class APSSignalingKeyStoreTests: MessagingTest {
    
    func testThatItCreatesKeyStoreFromUserClientWithKeys() {
        // given
        let keySize = Int(APSSignalingKeysStore.defaultKeyLengthBytes)
        let client = self.createSelfClient()
        let keys = APSSignalingKeysStore.createKeys()
        client.apsVerificationKey = keys.verificationKey
        client.apsDecryptionKey = keys.decryptionKey
        
        // when
        let keyStore = APSSignalingKeysStore(userClient: client)

        // then
        XCTAssertNotNil(keyStore)
        XCTAssertEqual(keyStore?.verificationKey.count, keySize)
        XCTAssertEqual(keyStore?.decryptionKey.count, keySize)
    }
    
    func testThatItReturnsNilKeyStoreFromUserClientWithoutKeys() {
        // given
        let client = self.createSelfClient()
        
        
        // when
        let keyStore = APSSignalingKeysStore(userClient: client)
        
        // then
        XCTAssertNil(keyStore)
    }
    
    func testThatItRandomizesTheKeys() {
        // when
        let keys1 = APSSignalingKeysStore.createKeys()
        let keys2 = APSSignalingKeysStore.createKeys()
        
        // then
        AssertOptionalNotNil(keys1) { keys1 in
            AssertOptionalNotNil(keys2) { keys2 in
                XCTAssertNotEqual(keys1.verificationKey, keys2.verificationKey)
                XCTAssertNotEqual(keys1.decryptionKey,   keys2.decryptionKey)
                XCTAssertNotEqual(keys1.verificationKey, keys1.decryptionKey)
                XCTAssertNotEqual(keys2.verificationKey, keys2.decryptionKey)
            }
        }
    }
    
    func testThatItReturnsKeysStoredInKeyChain() {
        // given
        let data1 = Data.randomEncryptionKey()
        let data2 = Data.randomEncryptionKey()
        
        ZMKeychain.setData(data1, forAccount: APSSignalingKeysStore.verificationKeyAccountName)
        ZMKeychain.setData(data2, forAccount: APSSignalingKeysStore.decryptionKeyAccountName)
        
        // when
        let keys = APSSignalingKeysStore.keysStoredInKeyChain()
        
        // then
        XCTAssertNotNil(keys)
        
        ZMKeychain.deleteAllKeychainItems(withAccountName: APSSignalingKeysStore.verificationKeyAccountName)
        ZMKeychain.deleteAllKeychainItems(withAccountName: APSSignalingKeysStore.decryptionKeyAccountName)
    }

}
