//

import Foundation

/**
 * Phases of registration.
 */

public enum RegistrationPhase: Equatable {
    case sendActivationCode(credentials: UnverifiedCredentials)
    case checkActivationCode(credentials: UnverifiedCredentials, code: String)
    case createUser(user: UnregisteredUser)
    case createTeam(team: UnregisteredTeam)
    case none
}
