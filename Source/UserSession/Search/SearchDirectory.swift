//

import Foundation


@objcMembers public class SearchDirectory : NSObject {
    
    let searchContext : NSManagedObjectContext
    let userSession : ZMUserSession
    var isTornDown = false
    
    deinit {
        assert(isTornDown, "`tearDown` must be called before SearchDirectory is deinitialized")
    }
    
    public init(userSession: ZMUserSession) {
        self.userSession = userSession
        self.searchContext = userSession.searchManagedObjectContext
    }

    /// Perform a search request.
    ///
    /// Returns a SearchTask which should be retained until the results arrive.
    public func perform(_ request: SearchRequest) -> SearchTask {
        let task = SearchTask(task: .search(searchRequest: request), context: searchContext, session: userSession)
        
        task.onResult { [weak self] (result, _) in
            self?.observeSearchUsers(result)
        }
        
        return task
    }
    
    /// Lookup a user by user Id and returns a search user in the directory results. If the user doesn't exists
    /// an empty directory result is returned.
    ///
    /// Returns a SearchTask which should be retained until the results arrive.
    public func lookup(userId: UUID) -> SearchTask {
        let task = SearchTask(task: .lookup(userId: userId), context: searchContext, session: userSession)
        
        task.onResult { [weak self] (result, _) in
            self?.observeSearchUsers(result)
        }
        
        return task
    }
    
    func observeSearchUsers(_ result : SearchResult) {
        let searchUserObserverCenter = userSession.managedObjectContext.searchUserObserverCenter
        result.directory.forEach(searchUserObserverCenter.addSearchUser)
        result.services.compactMap { $0 as? ZMSearchUser }.forEach(searchUserObserverCenter.addSearchUser)
    }
    
}

extension SearchDirectory: TearDownCapable {
    /// Tear down the SearchDirectory.
    ///
    /// NOTE: this must be called before releasing the instance
    public func tearDown() {
        guard userSession.managedObjectContext != nil else {
            isTornDown = true
            return
        }
        // Evict all cached search users
        userSession.managedObjectContext.zm_searchUserCache?.removeAllObjects()

        // Reset search user observer center to remove unnecessarily observed search users
        userSession.managedObjectContext.searchUserObserverCenter.reset()

        isTornDown = true
    }
}
