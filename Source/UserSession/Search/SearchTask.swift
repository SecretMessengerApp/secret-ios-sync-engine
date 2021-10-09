//

import Foundation
import WireUtilities

public class SearchTask {
    
    public enum Task {
        case search(searchRequest: SearchRequest)
        case lookup(userId: UUID)
    }
    
    public typealias ResultHandler = (_ result: SearchResult, _ isCompleted: Bool) -> Void
 
    fileprivate let session: ZMUserSession
    fileprivate let context: NSManagedObjectContext
    fileprivate let task: Task
    fileprivate var userLookupTaskIdentifier: ZMTaskIdentifier?
    fileprivate var directoryTaskIdentifier: ZMTaskIdentifier?
    fileprivate var handleTaskIdentifier: ZMTaskIdentifier?
    fileprivate var servicesTaskIdentifier: ZMTaskIdentifier?
    fileprivate var resultHandlers: [ResultHandler] = []
    fileprivate var result: SearchResult = SearchResult(contacts: [], teamMembers: [], addressBook: [],  directory: [], conversations: [], services: [])
    
    fileprivate var tasksRemaining = 0 {
        didSet {
            // only trigger handles if decrement to 0
            if oldValue > tasksRemaining {
                let isCompleted = tasksRemaining == 0
                resultHandlers.forEach { $0(result, isCompleted) }
                
                if isCompleted {
                    resultHandlers.removeAll()
                }
            }
        }
    }
    
    convenience init(request: SearchRequest, context: NSManagedObjectContext, session: ZMUserSession) {
        self.init(task: .search(searchRequest: request), context: context, session: session)
    }
    
    convenience init(lookupUserId userId: UUID, context: NSManagedObjectContext, session: ZMUserSession) {
        self.init(task: .lookup(userId: userId), context: context, session: session)
    }
    
    public init(task: Task, context: NSManagedObjectContext, session: ZMUserSession) {
        self.task = task
        self.session = session
        self.context = context
    }
    
    /// Add a result handler
    public func onResult(_ resultHandler : @escaping ResultHandler) {
        resultHandlers.append(resultHandler)
    }
    
    /// Cancel a previously started task
    public func cancel() {
        resultHandlers.removeAll()
        
        userLookupTaskIdentifier.flatMap(session.transportSession.cancelTask)
        directoryTaskIdentifier.flatMap(session.transportSession.cancelTask)
        servicesTaskIdentifier.flatMap(session.transportSession.cancelTask)
        handleTaskIdentifier.flatMap(session.transportSession.cancelTask)
        
        tasksRemaining = 0
    }
    
    /// Start the search task. Results will be sent to the result handlers
    /// added via the `onResult()` method.
    public func start() {
        performLocalSearch()

//        performRemoteSearch()
        performRemoteSearchByHandles()

        performUserLookup()
        performLocalLookup()
    }

    /// only search 'request.searchOptions.contains(.directory)'
    /// fetchLimit default is 10
    public func startRemoteSearch(fetchLimit: Int = 10) {
        performRemoteSearch(fetchLimit: fetchLimit)
    }
    
    /// only search 'request.searchOptions.contains(.directory)'
    /// seach with handle
    public func startHandleRemoteSearch() {
        performHandleRemoteSearch()
    }
}

extension SearchTask {


    /// look up a user ID from contacts and teamMmebers locally. 
    private func performLocalLookup() {
         guard case .lookup(let userId) = task else { return }

        tasksRemaining += 1

        context.performGroupedBlock {
            let selfUser = ZMUser.selfUser(in: self.context)

            var options = SearchOptions()

            options.updateForSelfUserTeamRole(selfUser: selfUser)

            ///search for the local user with matching user ID and active
//            let activeMembers = self.teamMembers(matchingQuery: "", team: selfUser.team, searchOptions: options)
//            let teamMembers = activeMembers.filter({ $0.remoteIdentifier == userId})

            let connectedUsers = self.connectedUsers(matchingQuery: "").filter({ $0.remoteIdentifier == userId})
            let result = SearchResult(contacts: connectedUsers,
                                      teamMembers: [],
                                      addressBook: [], directory: [], conversations: [], services: [])

            self.session.managedObjectContext.performGroupedBlock {
                self.result = self.result.union(withLocalResult: result.copy(on: self.session.managedObjectContext))

                self.tasksRemaining -= 1
            }
        }
    }

    func performLocalSearch() {
        guard case .search(let request) = task else { return }
        
        tasksRemaining += 1
        
        context.performGroupedBlock {
            
            let connectedUsers = request.searchOptions.contains(.contacts) ? self.connectedUsers(matchingQuery: request.normalizedQuery) : []
//            let teamMembers = request.searchOptions.contains(.teamMembers) ? self.teamMembers(matchingQuery: request.normalizedQuery, team: team, searchOptions: request.searchOptions) : []
            let conversations = request.searchOptions.contains(.conversations) ? self.conversations(matchingQuery: request.query) : []
            let result = SearchResult(contacts: connectedUsers, teamMembers: [], addressBook: [], directory: [], conversations: conversations, services: [])
            
            self.session.managedObjectContext.performGroupedBlock {
                self.result = self.result.union(withLocalResult: result.copy(on: self.session.managedObjectContext))
                
                if request.searchOptions.contains(.addressBook) {
                    self.result = self.result.extendWithContactsFromAddressBook(request.normalizedQuery, userSession: self.session)
                }
                
                self.tasksRemaining -= 1
            }
        }
    }
    
    func connectedUsers(matchingQuery query: String) -> [ZMUser] {
        guard let fetchRequest = ZMUser.sortedFetchRequest(with: ZMUser.predicateForConnectedUsers(withSearch: query)) else { return [] }
        return context.executeFetchRequestOrAssert(fetchRequest) as? [ZMUser] ?? []
    }
    
    func conversations(matchingQuery query: String) -> [ZMConversation] {
        guard let fetchRequest = ZMConversation.sortedFetchRequest(with: ZMConversation.predicate(forSearchQuery: query)) else { return [] }
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: ZMNormalizedUserDefinedNameKey, ascending: true)]
        var conversations = context.executeFetchRequestOrAssert(fetchRequest) as? [ZMConversation] ?? []
        
        if query.hasPrefix("@") {
            // if we are searching for a username only include conversations with matching displayName
            conversations = conversations.filter { $0.displayName.contains(query)}
        }
        
        let matchingPredicate = ZMConversation.userDefinedNamePredicate(forSearch: query)
        var matching : [ZMConversation] = []
        var nonMatching : [ZMConversation] = []
        
        // re-sort conversations without a matching userDefinedName to the end of the result list
        conversations.forEach { (conversation) in
            if matchingPredicate.evaluate(with: conversation) {
                matching.append(conversation)
            } else {
                nonMatching.append(conversation)
            }
        }
        
        return matching + nonMatching
    }
    
}

extension SearchTask {
    
    func performRemoteSearch(fetchLimit: Int = 10) {
        
        guard case .search(let searchRequest) = task else { return }
        
        tasksRemaining += 1
        
        context.performGroupedBlock {
            let request = type(of: self).searchRequestInDirectory(withQuery: searchRequest.query, fetchLimit: fetchLimit)
            
            request.add(ZMCompletionHandler(on: self.session.managedObjectContext, block: { [weak self] (response) in
                
                defer {
                    self?.tasksRemaining -= 1
                }
                
                guard
                    let session = self?.session,
                    let payload = response.payload?.asDictionary(),
                    let result = SearchResult(payload: payload, query: searchRequest.query, userSession: session)
                else {
                    return
                }
                
                if let updatedResult = self?.result.union(withDirectoryResult: result) {
                    self?.result = updatedResult
                }
            }))
            
            request.add(ZMTaskCreatedHandler(on: self.context, block: { [weak self] (taskIdentifier) in
                self?.directoryTaskIdentifier = taskIdentifier
            }))
            
            self.session.transportSession.enqueueOneTime(request)
        }
    }
    
    static func searchRequestInDirectory(withQuery query : String, fetchLimit: Int) -> ZMTransportRequest {
        var query = query
        
        if query.hasPrefix("@") {
            query = String(query[query.index(after: query.startIndex)...])
        }
        
        var url = URLComponents()
        url.path = "/search/contacts"
        url.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "size", value: String(fetchLimit))]
        let urlStr = url.string?.replacingOccurrences(of: "+", with: "%2B") ?? ""
        return ZMTransportRequest(getFromPath: urlStr)
    }
    
    
    func performUserLookup() {
        guard case .lookup(let userId) = task else { return }
        
        tasksRemaining += 1
        
        context.performGroupedBlock {
            let request  = type(of: self).searchRequestForUser(withUUID: userId)
            
            request.add(ZMCompletionHandler(on: self.session.managedObjectContext, block: { [weak self] (response) in
                defer {
                    self?.tasksRemaining -= 1
                }
                
                guard
                    let session = self?.session,
                    let payload = response.payload?.asDictionary(),
                    let result = SearchResult(userLookupPayload: payload, userSession: session)
                    else {
                        return
                }
                
                if let updatedResult = self?.result.union(withDirectoryResult: result) {
                    self?.result = updatedResult
                }
            }))
            
            request.add(ZMTaskCreatedHandler(on: self.context, block: { [weak self] (taskIdentifier) in
                self?.userLookupTaskIdentifier = taskIdentifier
            }))
            
            self.session.transportSession.enqueueOneTime(request)
        }
        
    }
    
    static func searchRequestForUser(withUUID uuid : UUID) -> ZMTransportRequest {
        return ZMTransportRequest(getFromPath: "/users/\(uuid.transportString())")
    }
    
}

extension SearchTask {
    
//    func performRemoteSearch() {
//        guard case .search(let searchRequest) = task, searchRequest.searchOptions.contains(.directory) else { return }
//    }
    
}

extension SearchTask {
    
    func performRemoteSearchByHandles() {
        guard case .search(let searchRequest) = task else { return }

        tasksRemaining += 1

        context.performGroupedBlock {
            let request = type(of: self).searchRequestInDirectory(withHandle: searchRequest.query)

            request.add(ZMCompletionHandler(on: self.session.managedObjectContext, block: { [weak self] (response) in

                defer {
                    self?.tasksRemaining -= 1
                }

                guard
                    let session = self?.session,
                    let payload = response.payload?.asArray(),
                    let userPayload = (payload.first as? ZMTransportData)?.asDictionary()
                    else {
                        return
                }

                guard
                    let handle = userPayload["handle"] as? String,
                    let name = userPayload["name"] as? String,
                    let id = userPayload["id"] as? String
                    else {
                        return
                }

                let document = ["handle": handle, "name": name, "id": id]
                let documentPayload = ["documents": [document]]
                guard let result = SearchResult(payload: documentPayload, query: searchRequest.query, userSession: session) else {
                    return
                }

                if let user = result.directory.first, !user.isSelfUser {
                    if let prevResult = self?.result {
                        // prepend result to prevResult only if it doesn't contain it
                        if !prevResult.directory.contains(user) {
                            self?.result = SearchResult(
                                contacts: prevResult.contacts,
                                teamMembers: [],
                                addressBook: prevResult.addressBook,
                                directory: result.directory + prevResult.directory,
                                conversations: prevResult.conversations,
                                services: []
                            )
                        }
                    } else {
                        self?.result = result
                    }
                }

            }))

            request.add(ZMTaskCreatedHandler(on: self.context, block: { [weak self] (taskIdentifier) in
                self?.handleTaskIdentifier = taskIdentifier
            }))

            self.session.transportSession.enqueueOneTime(request)
        }
    }

    static func searchRequestInDirectory(withHandle handle : String) -> ZMTransportRequest {
        var handle = handle.lowercased()
        
        if handle.hasPrefix("@") {
            handle = String(handle[handle.index(after: handle.startIndex)...])
        }
        
        var url = URLComponents()
        url.path = "/users"
        url.queryItems = [URLQueryItem(name: "handles", value: handle)]
        let urlStr = url.string?.replacingOccurrences(of: "+", with: "%2B") ?? ""
        return ZMTransportRequest(getFromPath: urlStr)
    }
    
    func performHandleRemoteSearch() {
        guard case .search(let searchRequest) = task, searchRequest.searchOptions.contains(.directory) else { return }
        
        tasksRemaining += 1
        
        context.performGroupedBlock {
            let request = type(of: self).searchRequestInDirectory(withHandle: searchRequest.query)
            
            request.add(ZMCompletionHandler(on: self.session.managedObjectContext, block: { [weak self] (response) in
                
                defer {
                    self?.tasksRemaining -= 1
                }
                
                guard
                    let session = self?.session,
                    let payload = response.payload?.asArray(),
                    let userPayload = (payload.first as? ZMTransportData)?.asDictionary()
                    else {
                        return
                }
                
                guard
                    let handle = userPayload["handle"] as? String,
                    let name = userPayload["name"] as? String,
                    let id = userPayload["id"] as? String
                    else {
                        return
                }
                
                let document = ["handle": handle, "name": name, "id": id]
                let documentPayload = ["documents": [document]]
                guard let result = SearchResult(payload: documentPayload, query: searchRequest.query, userSession: session, needFilterConnected: false) else {
                    return
                }
                if let updatedResult = self?.result.union(withDirectoryResult: result) {
                    self?.result = updatedResult
                }
            }))
            
            request.add(ZMTaskCreatedHandler(on: self.context, block: { [weak self] (taskIdentifier) in
                self?.directoryTaskIdentifier = taskIdentifier
            }))
            
            self.session.transportSession.enqueueOneTime(request)
        }
    }
}

extension SearchTask {
    
    static func servicesSearchRequest(teamIdentifier: UUID, query: String) -> ZMTransportRequest {
        var url = URLComponents()
        url.path = "/teams/\(teamIdentifier.transportString())/services/whitelisted"

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            url.queryItems = [URLQueryItem(name: "prefix", value: trimmedQuery)]
        }
        let urlStr = url.string?.replacingOccurrences(of: "+", with: "%2B") ?? ""
        return ZMTransportRequest(getFromPath: urlStr)
    }
}
