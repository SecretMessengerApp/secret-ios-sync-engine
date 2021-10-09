//

import Foundation

/**
 * Errors that can occur when requesting a company login session from a link.
 */

public enum ConmpanyLoginRequestError: Error, Equatable {
    /// The SSO link provided by the user was invalid.
    case invalidLink
}

/**
 * Errors that can occur within the company login flow.
 */

public enum CompanyLoginError: String {

    case unknownLabel = "0"
    case missingRequiredParameter = "-2063"
    case invalidCookie = "-67700"
    case tokenNotFound = "-25346"

    // MARK: - SAML

    case serverErrorUnsupportedSAML = "server-error-unsupported-saml"
    case badSuccessRedirect = "bad-success-redirect"
    case badFailureRedirect = "bad-failure-redirect"
    case badUsername = "bad-username"
    case badUpstream = "bad-upstream"
    case serverError = "server-error"
    case notFound = "not-found"
    case forbidden = "forbidden"
    case noMatchingAuthReq = "no-matching-auth-req"
    case insufficientPermissions = "insufficient-permissions"

    // MARK: - Metadata

    /// Parses the error label, or fallbacks to the default error if it is not known.
    init(label: String) {
        self = CompanyLoginError(rawValue: label) ?? .unknownLabel
    }

    /// The code to display to the user inside alerts.
    public var displayCode: String {
        switch self {
        case .unknownLabel, .missingRequiredParameter, .invalidCookie, .tokenNotFound:
            return rawValue

        case .serverErrorUnsupportedSAML: return "1"
        case .badSuccessRedirect: return "2"
        case .badFailureRedirect: return "3"
        case .badUsername: return "4"
        case .badUpstream: return "5"
        case .serverError: return "6"
        case .notFound: return "7"
        case .forbidden: return "8"
        case .noMatchingAuthReq: return "9"
        case .insufficientPermissions: return "10"
        }
    }

}
