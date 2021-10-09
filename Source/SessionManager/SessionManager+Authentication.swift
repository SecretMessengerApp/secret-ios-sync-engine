//

public extension SessionManager {
    
    static let previousSystemBootTimeContainer = "PreviousSystemBootTime"
    
    static var previousSystemBootTime: Date? {
        get {
            guard let data = ZMKeychain.data(forAccount: previousSystemBootTimeContainer),
                let string = String(data: data, encoding: .utf8),
                let timeInterval = TimeInterval(string) else {
                    return nil
            }
            return Date(timeIntervalSince1970: timeInterval)
        }
        set {
            guard let newValue = newValue,
                let data = "\(newValue.timeIntervalSince1970)".data(using: .utf8) else { return }
            
            ZMKeychain.setData(data, forAccount: previousSystemBootTimeContainer)
        }
    }
}
