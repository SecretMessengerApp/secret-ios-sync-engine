//

import Foundation
import WireUtilities

public protocol UnauthenticatedSessionDelegate: class {
    /// Update credentials for the corresponding user session. Returns true if the credentials were accepted.
    func session(session: UnauthenticatedSession, updatedCredentials credentials: ZMCredentials)  -> Bool
    func session(session: UnauthenticatedSession, updatedProfileImage imageData: Data)
    func session(session: UnauthenticatedSession, createdAccount account: Account)
    func session(session: UnauthenticatedSession, isExistingAccount account: Account) -> Bool
}

@objc public protocol UserInfoParser: class {
    @objc(accountExistsLocallyFromUserInfo:)
    func accountExistsLocally(from userInfo: UserInfo) -> Bool
    @objc(upgradeToAuthenticatedSessionWithUserInfo:)
    func upgradeToAuthenticatedSession(with userInfo: UserInfo)
}

private let log = ZMSLog(tag: "UnauthenticatedSession")


@objcMembers
public class UnauthenticatedSession: NSObject {
    
    /// **accountId** will be set if the unauthenticated session is associated with an existing account
    public internal(set) var accountId: UUID?
    public let groupQueue: DispatchGroupQueue
    private(set) public var authenticationStatus: ZMAuthenticationStatus!
    public let registrationStatus: RegistrationStatus 
    let reachability: ReachabilityProvider
    private(set) var operationLoop: UnauthenticatedOperationLoop!
    private let transportSession: UnauthenticatedTransportSessionProtocol
    fileprivate var tornDown = false

    weak var delegate: UnauthenticatedSessionDelegate?

    init(transportSession: UnauthenticatedTransportSessionProtocol, reachability: ReachabilityProvider, delegate: UnauthenticatedSessionDelegate?) {
        self.delegate = delegate
        self.groupQueue = DispatchGroupQueue(queue: .main)
        self.registrationStatus = RegistrationStatus()
        self.transportSession = transportSession
        self.reachability = reachability
        super.init()

        self.authenticationStatus = ZMAuthenticationStatus(groupQueue: groupQueue, userInfoParser: self)
        self.operationLoop = UnauthenticatedOperationLoop(
            transportSession: transportSession,
            operationQueue: groupQueue,
            requestStrategies: [
                ZMLoginTranscoder(groupQueue: groupQueue, authenticationStatus: authenticationStatus),
                ZMLoginCodeRequestTranscoder(groupQueue: groupQueue, authenticationStatus: authenticationStatus)!,
                RegistationCredentialVerificationStrategy(groupQueue: groupQueue, status: registrationStatus),
                RegistrationStrategy(groupQueue: groupQueue, status: registrationStatus, userInfoParser: self)
            ]
        )
    }

    deinit {
        precondition(tornDown, "Need to call tearDown before deinit")
    }

    func authenticationErrorIfNotReachable(_ block: () -> ()) {
        if self.reachability.mayBeReachable {
            block()
        } else {
            authenticationStatus.notifyAuthenticationDidFail(NSError(code: .networkError, userInfo:nil))
        }
    }
}

extension UnauthenticatedSession: TearDownCapable {
    public func tearDown() {
        operationLoop.tearDown()
        tornDown = true
    }
}

// MARK: - UserInfoParser

extension UnauthenticatedSession: UserInfoParser {

    public func accountExistsLocally(from info: UserInfo) -> Bool {
        let account = Account(userName: "", userIdentifier: info.identifier)
        guard let delegate = delegate else { return false }
        return delegate.session(session: self, isExistingAccount: account)
    }

    public func upgradeToAuthenticatedSession(with userInfo: UserInfo) {
        let account = Account(userName: "", userIdentifier: userInfo.identifier)
        let cookieStorage = transportSession.environment.cookieStorage(for: account)
        cookieStorage.authenticationCookieData = userInfo.cookieData
        self.authenticationStatus.authenticationCookieData = userInfo.cookieData
        self.delegate?.session(session: self, createdAccount: account)
    }

}
