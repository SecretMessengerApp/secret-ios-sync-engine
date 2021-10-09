//

import Foundation
import WireTesting

extension MockUser {

    var loginCredentials: LoginCredentials {
        return LoginCredentials(emailAddress: email, phoneNumber: phone, hasPassword: email != nil, usesCompanyLogin: false)
    }

}
