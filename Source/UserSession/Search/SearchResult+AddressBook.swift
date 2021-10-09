//

import Foundation
import Contacts

/// This is used for testing only
var debug_searchResultAddressBookOverride : AddressBookAccessor? = nil

extension SearchResult {
    
    /// Creates a new search result with the same results and additional
    /// results obtained by searching through the address book with the same query
    public func extendWithContactsFromAddressBook(_ query: String, userSession: ZMUserSession) -> SearchResult {
        /*
         When I have a search result obtained (either with a local search or from the BE) by matching on Wire
         users display names or handle, I also want to check if I have any address book contact in my local
         address book that match the query. However, matching local contacts might overlap in a number of ways
         with the users that I already found from the Wire search. The following code makes sure that such overlaps
         are not displayed twice (once for the Wire user, once for the address book contact).
         */
        let addressBook = AddressBookSearch(addressBook: debug_searchResultAddressBookOverride)
        
        // I don't need to find the address book contacts of users that I already found
        let identifiersOfAlreadyFoundUsers = contacts.compactMap { $0.addressBookEntry?.localIdentifier } + self.directory.compactMap { $0.user?.addressBookEntry?.localIdentifier }
        let allMatchingAddressBookContacts = addressBook.contactsMatchingQuery(query, identifiersToExclude: identifiersOfAlreadyFoundUsers)
        
        // There might also be contacts for which the local address book name match and which are also Wire users, but on Wire their name doesn't match,
        // so the Wire search did not return them. If I figure out which Wire users they match, I want to include those users into
        // the result as Wire user results, not an non-Wire address book results
        
        let (additionalUsersFromAddressBook, addressBookContactsWithoutUser) = contactsThatAreAlsoUsers(contacts: allMatchingAddressBookContacts,
                                                                                                        managedObjectContext: userSession.managedObjectContext)
        let searchUsersFromAddressBook = addressBookContactsWithoutUser.compactMap {  ZMSearchUser(contextProvider: userSession, contact: $0) }
        
        // of those users, which one are connected and which one are not?
        let additionalConnectedUsers = additionalUsersFromAddressBook
            .filter { $0.connection != nil }
            .compactMap { ZMSearchUser(contextProvider: userSession, user: $0) }
        let additionalNonConnectedUsers = additionalUsersFromAddressBook
            .filter { $0.connection == nil }
            .compactMap { ZMSearchUser(contextProvider: userSession, user: $0) }
        let connectedUsers = contacts.compactMap { ZMSearchUser(contextProvider: userSession, user: $0) }
        
        return SearchResult(contacts: contacts,
                            teamMembers: teamMembers,
                            addressBook: connectedUsers + additionalConnectedUsers + additionalNonConnectedUsers + searchUsersFromAddressBook,
                            directory: directory,
                            conversations: conversations,
                            services: services)
    }
    
    /// Returns users that are linked to the given address book contacts
    private func contactsThatAreAlsoUsers(contacts: [ZMAddressBookContact], managedObjectContext: NSManagedObjectContext) -> (users: [ZMUser], nonMatchedContacts: [ZMAddressBookContact]) {
        
        guard !contacts.isEmpty else {
            return (users: [], nonMatchedContacts: [])
        }
        
        var identifiersToContact = [String : ZMAddressBookContact]()
        contacts.forEach {
            guard let identifier = $0.localIdentifier else { return }
            identifiersToContact[identifier] = $0
        }
        
        let predicate = NSPredicate(format: "addressBookEntry.localIdentifier IN %@", Set(identifiersToContact.keys))
        guard let fetchRequest = ZMUser.sortedFetchRequest(with: predicate) else { return (users: [], nonMatchedContacts: []) }
        fetchRequest.returnsObjectsAsFaults = false
        let users = managedObjectContext.executeFetchRequestOrAssert(fetchRequest) as! [ZMUser]
        
        for user in users {
            guard let localIdentifier = user.addressBookEntry?.localIdentifier else { continue }
            identifiersToContact.removeValue(forKey: localIdentifier)
        }
        
        return (users: users, nonMatchedContacts: Array(identifiersToContact.values))
    }
}
