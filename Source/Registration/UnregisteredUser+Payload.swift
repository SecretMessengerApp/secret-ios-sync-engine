//

import Foundation
import WireDataModel

extension UnregisteredUser {

    /**
     * The dictionary payload that contains the resources to transmit to the backend
     * when registering the user.
     */

    var payload: ZMTransportData {
        guard self.isComplete else {
            fatalError("Attempt to register an incomplete user.")
        }

        var payload: [String: Any] = [:]

        switch credentials! {
        case .phone(let number):
            payload["phone"] = number
            payload["phone_code"] = verificationCode!

        case .email(let address):
            payload["email"] = address
            payload["email_code"] = verificationCode!
            payload["captch_token"] = captchToken
        }

        payload["accent_id"] = accentColorValue!.rawValue
        payload["name"] = name!
        payload["locale"] = NSLocale.formattedLocaleIdentifier()
        payload["label"] = CookieLabel.current.value
        payload["password"] = password

        return payload as ZMTransportData
    }

}
