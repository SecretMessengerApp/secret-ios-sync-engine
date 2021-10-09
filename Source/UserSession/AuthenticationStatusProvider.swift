//

import Foundation

@objc public protocol AuthenticationStatusProvider {
    var isAuthenticated: Bool { get }
}

extension ZMPersistentCookieStorage: AuthenticationStatusProvider {
    public var isAuthenticated: Bool {
        return authenticationCookieData != nil
    }
}
