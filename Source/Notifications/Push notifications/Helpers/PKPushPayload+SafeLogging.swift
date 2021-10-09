////

import Foundation
import PushKit

extension PKPushPayload: SafeForLoggingStringConvertible {
    public var safeForLoggingDescription: String {
        // The structure of APS payload is like this:
        //  {
        //      "aps" : {},
        //      "data" : {
        //          "data" : {
        //              "id" : "e919a0df-8e56-11e9-8123-22111a62954d",
        //          }
        //          "type" : "notice",
        //          "user" : "1a62954d-8123-11e9-8e56-2211e919a0df"
        //      }
        //  }
        let data = dictionaryPayload["data"] as? [String : Any]
        let payloadData = data?["data"] as? [String : String]
        let payloadID = payloadData?["id"]?.readableHash ?? "n/a"
        let userID = (data?["user"] as? String)?.readableHash ?? "n/a"
        return "id=\(payloadID) user=\(userID)"
    }
}
