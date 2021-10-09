//

import Foundation
import WireRequestStrategy

public extension AssetRequestFactory {
    // We need this method for visibility in ObjC
    
    @objc(profileImageAssetRequestWithData:)
    public func profileImageAssetRequest(with data: Data) -> ZMTransportRequest? {
        return upstreamRequestForAsset(withData: data, shareable: true, retention: .eternal)
    }
}
