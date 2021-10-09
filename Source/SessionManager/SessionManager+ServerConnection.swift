//

import Foundation

@objc
public protocol ServerConnectionObserver {
    
    @objc(serverConnectionDidChange:)
    func serverConnection(didChange serverConnection : ServerConnection)
    
}

@objc
public protocol ServerConnection {
    
    var isMobileConnection : Bool { get }
    var isOffline : Bool { get }
    
    func addServerConnectionObserver(_ observer: ServerConnectionObserver) -> Any
}

extension SessionManager {
    
    @objc public var serverConnection : ServerConnection? {
        return self
    }
    
}

extension SessionManager : ServerConnection {
    
    public var isOffline: Bool {
        return !reachability.mayBeReachable
    }
    
    public var isMobileConnection: Bool {
        return reachability.isMobileConnection
    }

    /// Add observer of server connection. Returns a token for de-registering the observer.
    public func addServerConnectionObserver(_ observer: ServerConnectionObserver) -> Any {
        
        return reachability.addReachabilityObserver(on: .main) { [weak self, weak observer] _ in
            guard let `self` = self else { return }
            observer?.serverConnection(didChange: self)
        }
    }
    
}
