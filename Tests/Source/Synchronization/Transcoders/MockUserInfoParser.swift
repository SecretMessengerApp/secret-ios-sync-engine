//


@objcMembers public class MockUserInfoParser: NSObject, UserInfoParser {
    
    public var accountExistsLocallyCalled = 0
    public var existingAccounts = [UserInfo]()

    public func accountExistsLocally(from userInfo: UserInfo) -> Bool {
        accountExistsLocallyCalled += 1
        return existingAccounts.contains(userInfo)
    }

    public var upgradeToAuthenticatedSessionCallCount = 0
    public var upgradeToAuthenticatedSessionUserInfos = [UserInfo]()
    
    public func upgradeToAuthenticatedSession(with userInfo: UserInfo) {
        upgradeToAuthenticatedSessionCallCount += 1
    }

    public var userId: UUID?
    public var userIdentifierCalled = 0
    public func userIdentifier(from response: ZMTransportResponse) -> UUID? {
        userIdentifierCalled += 1
        return userId
    }

}
