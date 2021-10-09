//

import Foundation
import WireDataModel

public struct SearchOptions : OptionSet {
    public let rawValue: Int

    /// Users you are connected to via connection request
    public static let contacts = SearchOptions(rawValue: 1 << 0)
    /// Users found in your address book
    public static let addressBook = SearchOptions(rawValue: 1 << 1)
    /// Users which are a member of the same team as you
    public static let teamMembers = SearchOptions(rawValue: 1 << 2)
    /// Exclude team members which aren't in an active conversation with you
    public static let excludeNonActiveTeamMembers = SearchOptions(rawValue: 1 << 3)
    /// Exclude team members with the role .partner which aren't in an active conversation with you
    public static let excludeNonActivePartners = SearchOptions(rawValue: 1 << 4)
    /// Users from the public directory
    public static let directory = SearchOptions(rawValue: 1 << 5)
    /// Group conversations you are or were a participant of
    public static let conversations = SearchOptions(rawValue: 1 << 6)
    /// Services which are enabled in your team
    public static let services = SearchOptions(rawValue: 1 << 7)
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
}

extension SearchOptions {
    public mutating func updateForSelfUserTeamRole(selfUser: ZMUser) {
        if selfUser.teamRole == .partner {
            insert(.excludeNonActiveTeamMembers)
            remove(.directory)
        } else {
            insert(.excludeNonActivePartners)
        }
    }
}


public struct SearchRequest {
    
    let maxQueryLength = 200
    
    public init(query: String, searchOptions: SearchOptions, team: Team? = nil) {
        self.query = query.truncated(at: maxQueryLength)
        self.searchOptions = searchOptions
        self.team = team
    }
    
    var team : Team? = nil
    let query : String
    let searchOptions: SearchOptions
    
    var normalizedQuery: String {
        return query.normalizedAndTrimmed()
    }
    
}

fileprivate extension String {
    
    func normalizedAndTrimmed() -> String {
        guard let normalized = self.normalizedForSearch() as String? else { return "" }
        return normalized.trimmingCharacters(in: .whitespaces)
    }
    
}
