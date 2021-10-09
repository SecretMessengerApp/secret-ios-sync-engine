//

import Foundation

extension ZMCredentials {
    var isInvalid: Bool {
        let noEmail = email?.isEmpty ?? true
        let noPassword = password?.isEmpty ?? true
        let noNumber = phoneNumber?.isEmpty ?? true
        let noVerificationCode = phoneNumberVerificationCode?.isEmpty ?? true
        return (noEmail || noPassword) && (noNumber || noVerificationCode)
    }
}

extension UnauthenticatedSession {

    @objc(continueAfterBackupImportStep)
    public func continueAfterBackupImportStep() {
        authenticationStatus.continueAfterBackupImportStep()
    }
        
    /// Attempt to log in with the given credentials
    @objc(loginWithCredentials:)
    public func login(with credentials: ZMCredentials) {
        let updatedCredentialsInUserSession = delegate?.session(session: self, updatedCredentials: credentials) ?? false
        
        guard !updatedCredentialsInUserSession else { return }
        
        if credentials.isInvalid {
            authenticationStatus.notifyAuthenticationDidFail(NSError(code: .needsCredentials, userInfo: nil))
        } else {
            authenticationErrorIfNotReachable {
                self.authenticationStatus.prepareForLogin(with: credentials)
                RequestAvailableNotification.notifyNewRequestsAvailable(nil)
            }
        }
    }
    
    /// Requires a phone verification code for login. Returns NO if the phone number was invalid
    @objc(requestPhoneVerificationCodeForLogin:)
    @discardableResult public func requestPhoneVerificationCodeForLogin(phoneNumber: String) -> Bool {
        do {
            var phoneNumber: String? = phoneNumber
            try ZMUser.validate(phoneNumber: &phoneNumber)
        } catch {
            return false
        }

        authenticationErrorIfNotReachable {
            self.authenticationStatus.prepareForRequestingPhoneVerificationCode(forLogin: phoneNumber)
            RequestAvailableNotification.notifyNewRequestsAvailable(nil)
        }
        return true
    }
    
    func addAuthenticationObserver(_ observer: PreLoginAuthenticationObserver) -> Any {
        return PreLoginAuthenticationNotification.register(observer, context: authenticationStatus)
    }
    
}
