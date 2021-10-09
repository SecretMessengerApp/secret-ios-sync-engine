//

import Foundation
import PushKit

@testable import WireSyncEngine


class PushPayloadMock: PKPushPayload {
    
    let mockDictionaryPayload: [AnyHashable : Any]
    
    init(dictionaryPayload: [AnyHashable : Any]) {
        mockDictionaryPayload = dictionaryPayload
        
        super.init()
    }
    
    override var dictionaryPayload: [AnyHashable : Any] {
        return mockDictionaryPayload
    }
    
}

class PushCredentialsMock: PKPushCredentials {
    
    let mockToken: Data
    let mockType: PKPushType
    
    init(token: Data, type: PKPushType) {
        mockToken = token
        mockType = type
        
        super.init()
    }
    
    override var token: Data {
        return mockToken
    }
    
    override var type: PKPushType {
        return mockType
    }
    
}


@objcMembers
class PushRegistryMock: PKPushRegistry {
    
    var mockPushToken: Data?
    
    func mockIncomingPushPayload(_ payload: [AnyHashable : Any], completion: (() -> Void)? = nil) {
        
        if #available(iOS 11.0, *) {
            delegate?.pushRegistry!(self, didReceiveIncomingPushWith: PushPayloadMock(dictionaryPayload: payload), for: .voIP, completion: {
                completion?()
            })
        }
    }
    
    func invalidatePushToken() {
        mockPushToken = nil
        delegate?.pushRegistry?(self, didInvalidatePushTokenFor: .voIP)
    }
    
    func updatePushToken(_ token: Data) {
        mockPushToken = token
        delegate?.pushRegistry(self, didUpdate: PushCredentialsMock(token: token, type: .voIP), for: .voIP)
    }
    
    override func pushToken(for type: PKPushType) -> Data? {
        return mockPushToken
    }
    
}
