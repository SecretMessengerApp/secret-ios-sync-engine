//

import Foundation


@objc public class RequestLoopAnalyticsTracker : NSObject {

    private let ignoredSuffixes = [
        "/typing"
    ]
    
    weak var analytics: AnalyticsType?
    
    @objc(initWithAnalytics:)
    public init(with analytics : AnalyticsType?) {
        self.analytics = analytics
    }

    /// Track a loop at the given path.
    /// The path will be sanitized (UUIDs will be removed).
    /// - parameter path: The path to track a request loop for.
    /// - returns: `true` in case the tracking has been performed, `false` otherwise (e.g. when the path was in the ignored paths list).
    @objc(tagWithPath:)
    public func tag(with path: String) -> Bool {
        guard nil == ignoredSuffixes.first(where: path.hasSuffix) else { return false }
        if let analytics = analytics {
            analytics.tagEvent("request.loop", attributes: ["path": path.sanitizePath() as NSObject])
            return true
        } else {
            return false
        }
    }
}


extension String {

    static var uuidRegexp: NSRegularExpression? = {
        return try? NSRegularExpression(
            pattern: "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{3,12}",
            options: .caseInsensitive
        )
    }()

    static var clientIdRegexp: NSRegularExpression? = {
        return try? NSRegularExpression(
            pattern: "[a-f0-9]{15,16}",
            options: .caseInsensitive
        )
    }()

    func sanitizePath()-> String {
        guard let uuidRegexp = String.uuidRegexp, let clientIdRegexp = String.clientIdRegexp else { return self }
        let mutableString = NSMutableString(string: self)
        let template = "{id}"
        uuidRegexp.replaceMatches(in: mutableString, options: [], range: NSMakeRange(0, mutableString.length), withTemplate: template)
        clientIdRegexp.replaceMatches(in: mutableString, options: [], range: NSMakeRange(0, mutableString.length), withTemplate: template)
        let swiftString = (mutableString as String).replacingOccurrences(of: ",\(template)", with: "")
        return swiftString
    }
}
