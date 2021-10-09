//

import Foundation

extension ZMUserSessionErrorCode: LocalizedError {
    public var errorDescription: String? {
        let bundle = Bundle(for: ZMUserSession.self)
        switch self {
        case .blacklistedEmail:
            return bundle.localizedString(forKey: "user_session.error.blacklisted-email", value: nil, table: "ZMLocalizable")
        case .emailIsAlreadyRegistered:
            return bundle.localizedString(forKey: "user_session.error.email-exists", value: nil, table: "ZMLocalizable")
        case .invalidEmail:
            return bundle.localizedString(forKey: "user_session.error.invalid-email", value: nil, table: "ZMLocalizable")
        case .invalidActivationCode:
            return bundle.localizedString(forKey: "user_session.error.invalid-code", value: nil, table: "ZMLocalizable")
        case .unknownError:
            return bundle.localizedString(forKey: "user_session.error.unknown", value: nil, table: "ZMLocalizable")
        case .unauthorizedEmail:
            return bundle.localizedString(forKey: "user_session.error.unknown", value: nil, table: "ZMLocalizable")
        default:
            return nil
        }
    }
}
