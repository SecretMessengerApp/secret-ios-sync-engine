//

import WireSystem

enum BuildType: Equatable {
    case production
    case alpha
    case development
    case `internal`
    case custom(bundleID: String)

    init(bundleID: String) {
        switch bundleID {
        case "com.secrect.qhsj": self = .production
        case "com.secret.alpha": self = .alpha
        case "com.secret.development": self = .development
        case "com.secret.beta": self = .internal
        default: self = .custom(bundleID: bundleID)
        }
    }
    
    var certificateName: String {
        switch self {
        case .production:
            return "Qhsj"
        case .alpha:
            return "Alpha"
        case .development:
            return "Development"
        case .internal:
            return "Beta"
        case .custom(let bundleID):
            return bundleID
        }
    }
    
    var bundleID: String {
        switch self {
        case .production:
            return "com.secrect.qhsj"
        case .alpha:
            return "com.secret.alpha"
        case .development:
            return "com.secret.development"
        case .internal:
            return "com.secret.beta"
        case .custom(let bundleID):
            return bundleID
        }
        
    }
}
