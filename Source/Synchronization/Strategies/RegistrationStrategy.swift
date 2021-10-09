//

import Foundation

final class RegistrationStrategy : NSObject {
    let registrationStatus: RegistrationStatusProtocol
    weak var userInfoParser: UserInfoParser?
    var registrationSync: ZMSingleRequestSync!

    init(groupQueue: ZMSGroupQueue, status : RegistrationStatusProtocol, userInfoParser: UserInfoParser) {
        registrationStatus = status
        self.userInfoParser = userInfoParser
        super.init()
        registrationSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: groupQueue)
    }
}

extension RegistrationStrategy : ZMSingleRequestTranscoder {
    func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        switch (registrationStatus.phase) {
        case let .createUser(user):
            return ZMTransportRequest(path: "/register", method: .methodPOST, payload: user.payload)
        case let .createTeam(team):
            return ZMTransportRequest(path: "/register", method: .methodPOST, payload: team.payload)
        default:
            fatal("Generating request for invalid phase: \(registrationStatus.phase)")
        }
    }

    func didReceive(_ response: ZMTransportResponse, forSingleRequest sync: ZMSingleRequestSync) {
        if response.result == .success {
            response.extractUserInfo().apply {
                userInfoParser?.upgradeToAuthenticatedSession(with: $0)
            }
            registrationStatus.success()
        } else {
            let error = NSError.blacklistedEmail(with: response) ??
                NSError.invalidActivationCode(with: response) ??
                NSError.emailAddressInUse(with: response) ??
                NSError.phoneNumberIsAlreadyRegisteredError(with: response) ??
                NSError.invalidEmail(with: response) ??
                NSError.invalidPhoneNumber(withReponse: response) ??
                NSError.unauthorizedEmailError(with: response) ??
                NSError(code: .unknownError, userInfo: [:])
            registrationStatus.handleError(error)
        }
    }
}

extension RegistrationStrategy : RequestStrategy {
    func nextRequest() -> ZMTransportRequest? {
        switch (registrationStatus.phase) {
        case .createTeam, .createUser:
            registrationSync.readyForNextRequestIfNotBusy()
            return registrationSync.nextRequest()
        default:
            return nil
        }
    }
}
