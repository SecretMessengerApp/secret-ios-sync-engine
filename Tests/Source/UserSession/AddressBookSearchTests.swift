//

import Foundation
import XCTest
@testable import WireSyncEngine

class AddressBookSearchTests : MessagingTest {
    
    var sut : WireSyncEngine.AddressBookSearch!
    var addressBook : AddressBookFake!
    
    override func setUp() {
        super.setUp()
        self.addressBook = AddressBookFake()
        self.sut = WireSyncEngine.AddressBookSearch(addressBook: self.addressBook)
    }
    
    override func tearDown() {
        self.sut = nil
        self.addressBook = nil
        super.tearDown()
    }
}

// MARK: - Search query
extension AddressBookSearchTests {
    
    func testThatItSearchesByNameWithMatch() {
        
        // given
        addressBook.fakeContacts = [
            FakeAddressBookContact(firstName: "Olivia", emailAddresses: ["oli@example.com"], phoneNumbers: []),
            FakeAddressBookContact(firstName: "Ada", emailAddresses: [], phoneNumbers: ["+155505012"])
        ]
        
        // when
        let result = Array(sut.contactsMatchingQuery("ivi", identifiersToExclude: []))
        
        // then
        XCTAssertEqual(result.count, 1)
        guard result.count == 1 else { return }
        XCTAssertEqual(result[0].emailAddresses, ["oli@example.com"])
    }
    
    func testThatItSearchesByNameWithMatchExcludingIdentifiers() {
        
        // given
        let identifier = "233124"
        addressBook.fakeContacts = [
            FakeAddressBookContact(firstName: "Olivia 1", emailAddresses: ["oli@example.com"], phoneNumbers: [], identifier: identifier),
            FakeAddressBookContact(firstName: "Olivia 2", emailAddresses: [], phoneNumbers: ["+155505012"])
        ]
        
        // when
        let result = Array(sut.contactsMatchingQuery("ivi", identifiersToExclude: [identifier]))
        
        // then
        XCTAssertEqual(result.count, 1)
        guard result.count == 1 else { return }
        XCTAssertEqual(result[0].firstName, "Olivia 2")
    }
    
    func testThatItSearchesByNameWithNoMatch() {
        
        // given
        addressBook.fakeContacts = [
            FakeAddressBookContact(firstName: "Olivia", emailAddresses: ["oli@example.com"], phoneNumbers: []),
            FakeAddressBookContact(firstName: "Ada", emailAddresses: [], phoneNumbers: ["+155505012"])
        ]
        
        // when
        let result = Array(sut.contactsMatchingQuery("Nadia", identifiersToExclude: []))
        
        // then
        XCTAssertEqual(result.count, 0)
    }
}

