//

import Foundation

extension NSError {
    @objc public static var ZMUserSessionErrorDomain = "ZMUserSession"

    @objc(initWitUserSessionErrorWithErrorCode:userInfo:)
    public convenience init(code: ZMUserSessionErrorCode, userInfo: [String : Any]?) {
        var info = userInfo ?? [:]
        if let description = code.errorDescription {
            info[NSLocalizedDescriptionKey] = description
        }
        self.init(domain: NSError.ZMUserSessionErrorDomain, code: Int(code.rawValue), userInfo: info)
    }
}
