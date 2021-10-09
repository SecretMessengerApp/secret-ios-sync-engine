//

import UIKit

/**
 * An object that detects company login request wihtin the pasteboard.
 *
 * A session request is a string formatted as `wire-[UUID]`.
 */

public final class CompanyLoginRequestDetector: NSObject {

    /**
     * A struct that describes the result of a login code detection operation..
     */

    public struct DetectorResult: Equatable {
        public let code: String // The detected shared identity login code.
        public let isNew: Bool  // Weather or not the code changed since the last check.
    }

    private let pasteboard: Pasteboard
    private let processQueue = DispatchQueue(label: "WireSyncEngine.SharedIdentitySessionRequestDetector")
    private var previousChangeCount: Int?
    
    // MARK: - Initialization

    /// Returns the detector that uses the system pasteboard to detect session requests.
    public static let shared = CompanyLoginRequestDetector(pasteboard: UIPasteboard.general)

    /// Creates a detector that uses the specified pasteboard to detect session requests.
    public init(pasteboard: Pasteboard) {
        self.pasteboard = pasteboard
    }

    // MARK: - Detection

    /**
     * Tries to extract the session request code from the current pasteboard.
     *
     * The processing will be done on a background queue, and the completion
     * handler will be called on the main thread with the result.
     */

    public func detectCopiedRequestCode(_ completionHandler: @escaping (DetectorResult?) -> Void) {
        func complete(_ result: DetectorResult?) {
            previousChangeCount = pasteboard.changeCount
            DispatchQueue.main.async {
                completionHandler(result)
            }
        }

        processQueue.async { [pasteboard, previousChangeCount] in
            guard let text = pasteboard.text else { return complete(nil) }
            guard let code = CompanyLoginRequestDetector.requestCode(in: text) else { return complete(nil) }

            let validText = "wire-" + code.uuidString
            let isNew = pasteboard.changeCount != previousChangeCount
            complete(.init(code: validText, isNew: isNew))
        }
    }

    /**
     * Tries to extract the request ID from the contents of the text.
     */

    public static func requestCode(in string: String) -> UUID? {
        guard let prefixRange = string.range(of: "wire-") else {
            return nil
        }

        guard let endIndex = string.index(prefixRange.upperBound, offsetBy: 36, limitedBy: string.endIndex) else {
            return nil
        }

        let codeString = string[prefixRange.upperBound ..< endIndex]
        return UUID(uuidString: String(codeString))
    }

    /**
     * Validates the session request code from the user input.
     */

    public static func isValidRequestCode(in string: String) -> Bool {
        return requestCode(in: string) != nil
    }

}
