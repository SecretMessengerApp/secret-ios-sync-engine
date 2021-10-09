//

import Foundation

@objcMembers public class Blacklist: NSObject {
    public let minVersion: String
    public let excludedVersions: [String]
    
    public init?(json: [AnyHashable: Any]) {
        guard let minVersion = json["min_version"] as? String,
            let excludedVersions = json["exclude"] as? [String] else {
            return nil
        }
        self.minVersion = minVersion
        self.excludedVersions = excludedVersions
    }
}
