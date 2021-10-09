//

import Foundation

/**
 * An object that provides
 */

public protocol Pasteboard: class {

    /// The text copied by the user, if any.
    var text: String? { get }
    var changeCount: Int { get }

}

extension UIPasteboard: Pasteboard {

    public var text: String? {
        if #available(iOS 10, *) {
            guard self.hasStrings else {
                return nil
            }
        }
        return self.string
    }

}
