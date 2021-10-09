//

import Foundation

extension SessionManager {

    public enum SwitchBackendError: Swift.Error {
        case loggedInAccounts
        case invalidBackend
    }
    
    public typealias CompletedSwitch = (Result<BackendEnvironment>) -> ()
    
    public func canSwitchBackend() -> SwitchBackendError? {
        guard accountManager.accounts.isEmpty else { return .loggedInAccounts }

        return nil
    }
    
    public func switchBackend(configuration url: URL, completed: @escaping CompletedSwitch) {
        if let error = canSwitchBackend() {
            completed(.failure(error))
            return
        }
        let group = self.dispatchGroup
        group?.enter()
        BackendEnvironment.fetchEnvironment(url: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let environment):
                    self.environment = environment
                    self.unauthenticatedSession = nil
                    completed(.success(environment))
                case .failure:
                    completed(.failure(SwitchBackendError.invalidBackend))
                }
                group?.leave()
            }
        }
    }
}
