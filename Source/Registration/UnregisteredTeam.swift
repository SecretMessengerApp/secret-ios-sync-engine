//

import Foundation

/**
 * An object containing the details required to create a team.
 */

public struct UnregisteredTeam: Equatable {

    public let teamName: String
    public let email: String
    public let emailCode: String
    public let fullName: String
    public let password: String
    public let accentColor: ZMAccentColor
    public let locale: String
    public let label: UUID?

    public init(teamName: String, email: String, emailCode: String, fullName: String, password: String, accentColor: ZMAccentColor) {
        self.teamName = teamName
        self.email = email
        self.emailCode = emailCode
        self.fullName = fullName
        self.password = password
        self.accentColor = accentColor
        self.locale = NSLocale.formattedLocaleIdentifier()!
        self.label = UIDevice.current.identifierForVendor
    }

    var payload: ZMTransportData {
        return [
            "email" : email,
            "email_code" : emailCode,
            "team" : [
                "name" : teamName,
                "icon" : "abc"
            ],
            "accent_id" : accentColor.rawValue,
            "locale" : locale,
            "name" : fullName,
            "password" : password,
            "label" : label?.uuidString ?? UUID().uuidString
            ] as ZMTransportData
    }
}
