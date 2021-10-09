//

import Foundation
import Contacts

/// Search for contacts in the address book
class AddressBookSearch {
    
    /// Maximum number of contacts to consider when matching/searching,
    /// for performance reasons
    fileprivate let maximumSearchRange : UInt = 3000
    
    /// Address book
    fileprivate let addressBook : AddressBookAccessor?
    
    init(addressBook : AddressBookAccessor? = nil) {
        self.addressBook = addressBook ?? AddressBook.factory()
    }
}

// MARK: - Search contacts
extension AddressBookSearch {

    /// Returns address book contacts matching the query, excluding the one with the given identifier
    func contactsMatchingQuery(_ query: String, identifiersToExclude: [String]) -> [ZMAddressBookContact] {
        let excluded = Set(identifiersToExclude)
        let addressBookMatches = self.addressBook?.contacts(matchingQuery: query.lowercased()) ?? []
        
        return addressBookMatches.filter { contact in
            guard let identifier = contact.localIdentifier else {
                return true
            }
            return !excluded.contains(identifier)
        }
    }
}
