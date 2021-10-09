//

import Foundation


final class RegistationCredentialVerificationStrategy : NSObject {
    let registrationStatus: RegistrationStatusProtocol
    var codeSendingSync: ZMSingleRequestSync!

    init(groupQueue: ZMSGroupQueue, status : RegistrationStatusProtocol) {
        registrationStatus = status
        super.init()
        codeSendingSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: groupQueue)
    }
}

extension RegistationCredentialVerificationStrategy : ZMSingleRequestTranscoder {
    func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        let currentStatus = registrationStatus
        var payload : [String: Any]
        var path : String

        switch (currentStatus.phase) {
        case let .sendActivationCode(credentials):
            path = "/activate/send"
            payload = [credentials.type: credentials.rawValue,
                       "locale": NSLocale.formattedLocaleIdentifier()!]
        case let .checkActivationCode(credentials, code):
            path = "/activate"
            payload = [credentials.type: credentials.rawValue,
                       "code": code,
                       "dryrun": true]
        default:
            fatal("Generating request for invalid phase: \(currentStatus.phase)")
        }

        return ZMTransportRequest(path: path, method: .methodPOST, payload: payload as ZMTransportData)
    }

    func didReceive(_ response: ZMTransportResponse, forSingleRequest sync: ZMSingleRequestSync) {
        if response.result == .success {
            registrationStatus.success()
        }
        else {
            let error : NSError

            switch (registrationStatus.phase) {
            case .sendActivationCode(let credentials):
                let decodedError: NSError?
                switch credentials {
                case .email:
                    decodedError = NSError.blacklistedEmail(with: response) ??
                    NSError.emailAddressInUse(with: response) ??
                    NSError.invalidEmail(with: response)

                case .phone:
                    decodedError = NSError.phoneNumberIsAlreadyRegisteredError(with: response) ??
                    NSError.invalidPhoneNumber(withReponse: response)
                }

                error = decodedError ?? NSError(code: .unknownError, userInfo: [:])
            case .checkActivationCode:
                error = NSError.invalidActivationCode(with: response) ??
                    NSError(code: .unknownError, userInfo: [:])
            default:
                fatal("Error occurs for invalid phase: \(registrationStatus.phase)")
            }
            registrationStatus.handleError(error)
        }
    }

}

extension RegistationCredentialVerificationStrategy : RequestStrategy {
    func nextRequest() -> ZMTransportRequest? {
        switch (registrationStatus.phase) {
        case .sendActivationCode, .checkActivationCode:
            codeSendingSync.readyForNextRequestIfNotBusy()
            return codeSendingSync.nextRequest()
        default:
            return nil
        }
    }
}
