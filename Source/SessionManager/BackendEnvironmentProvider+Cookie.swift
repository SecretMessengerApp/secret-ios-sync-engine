//

import WireTransport

extension BackendEnvironmentProvider {
    func cookieStorage(for account: Account) -> ZMPersistentCookieStorage {
        let backendURL = self.backendURL.host!
        return ZMPersistentCookieStorage(forServerName: backendURL, userIdentifier: account.userIdentifier)
    }
    
    public func isAuthenticated(_ account: Account) -> Bool {
        let cookieStorage = self.cookieStorage(for: account)
        
        if let expirationDate = cookieStorage.authenticationCookieExpirationDate {
            return expirationDate.timeIntervalSinceNow > 0
        } else {
            return cookieStorage.authenticationCookieData != nil
        }
    }
    
    func tributaryURL(for account: Account) -> URL? {
        guard let tributaryURLs = UserDefaults.standard.object(forKey: "tributaryURLs") as? [String: Any] else { return nil }
        if let url = tributaryURLs.first(where: {
            return $0.key == account.userIdentifier.transportString()
        })?.value as? String {
            return URL.init(string: url)
        }
        return nil
    }
    
}
