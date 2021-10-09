//

import Foundation

public struct SearchResult {
    public let contacts:      [ZMUser]
    public let teamMembers:   [Member]
    public let addressBook:   [ZMSearchUser]
    public let directory:     [ZMSearchUser]
    public let conversations: [ZMConversation]
    public let services:      [ServiceUser]
}

extension SearchResult {
    
    public init?(payload: [AnyHashable : Any], query: String, userSession: ZMUserSession, needFilterConnected: Bool) {
        guard let documents = payload["documents"] as? [[String : Any]] else {
            return nil
        }
        
        let isHandleQuery = query.hasPrefix("@")
        let queryWithoutAtSymbol = (isHandleQuery ? String(query[query.index(after: query.startIndex)...]) : query).lowercased()
        
        let filteredDocuments = documents.filter { (document) -> Bool in
            let name = document["name"] as? String
            let handle = document["handle"] as? String
            
            return !isHandleQuery || name?.hasPrefix("@") ?? true || handle?.contains(queryWithoutAtSymbol) ?? false
        }
        
        let searchUsers = ZMSearchUser.searchUsers(from: filteredDocuments, contextProvider: userSession)
        
        contacts = []
        teamMembers = []
        addressBook = []
        directory = searchUsers
        conversations = []
        services = []
    }
    
    public init?(payload: [AnyHashable : Any], query: String, userSession: ZMUserSession) {
        guard let documents = payload["documents"] as? [[String : Any]] else {
            return nil
        }
        
        let isHandleQuery = query.hasPrefix("@")
        let queryWithoutAtSymbol = (isHandleQuery ? String(query[query.index(after: query.startIndex)...]) : query).lowercased()

        let filteredDocuments = documents.filter { (document) -> Bool in
            let name = document["name"] as? String
            let handle = document["handle"] as? String
            
            return !isHandleQuery || name?.hasPrefix("@") ?? true || handle?.contains(queryWithoutAtSymbol) ?? false
        }
        
        let searchUsers = ZMSearchUser.searchUsers(from: filteredDocuments, contextProvider: userSession)
        
        contacts = []
        teamMembers = []
        addressBook = []
        directory = searchUsers.filter({ !$0.isConnected && !$0.isTeamMember })
        conversations = []
        services = []
    }
    
    public init?(servicesPayload servicesFullPayload: [AnyHashable : Any], query: String, userSession: ZMUserSession) {
        guard let servicesPayload = servicesFullPayload["services"] as? [[String : Any]] else {
            return nil
        }
        
        let searchUsersServices = ZMSearchUser.searchUsers(from: servicesPayload, contextProvider: userSession)
        
        contacts = []
        teamMembers = []
        addressBook = []
        directory = []
        conversations = []
        services = searchUsersServices
    }
    
    public init?(userLookupPayload: [AnyHashable : Any], userSession: ZMUserSession) {
        guard let userLookupPayload = userLookupPayload as? [String : Any],
              let searchUser = ZMSearchUser.searchUser(from: userLookupPayload, contextProvider: userSession),
              searchUser.user == nil ||
              searchUser.user?.isTeamMember == false else {
            return nil
        }
        
        contacts = []
        teamMembers = []
        addressBook = []
        directory = [searchUser]
        conversations = []
        services = []
    }
    
    func copy(on context: NSManagedObjectContext) -> SearchResult {
        
        let copiedContacts = contacts.compactMap { context.object(with: $0.objectID) as? ZMUser }
        let copiedTeamMembers = teamMembers.compactMap { context.object(with: $0.objectID) as? Member }
        let copiedConversations = conversations.compactMap { context.object(with: $0.objectID) as? ZMConversation }
        
        return SearchResult(contacts: copiedContacts, teamMembers: copiedTeamMembers, addressBook: addressBook, directory: directory, conversations: copiedConversations, services: services)
    }
    
    func union(withLocalResult result: SearchResult) -> SearchResult {
        return SearchResult(contacts: result.contacts, teamMembers: result.teamMembers, addressBook: result.addressBook, directory: directory, conversations: result.conversations, services: services)
    }
    
    func union(withServiceResult result: SearchResult) -> SearchResult {
        return SearchResult(contacts: contacts,
                            teamMembers: teamMembers,
                            addressBook: addressBook,
                            directory: directory,
                            conversations: conversations,
                            services: result.services)
    }
    
    func union(withDirectoryResult result: SearchResult) -> SearchResult {
        return SearchResult(contacts: contacts,
                            teamMembers: teamMembers,
                            addressBook: addressBook,
                            directory: result.directory,
                            conversations: conversations,
                            services: services)
    }
    
}
