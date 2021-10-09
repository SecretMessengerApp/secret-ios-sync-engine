//

import Foundation
import AddressBook
@testable import WireSyncEngine

class AddressBookTests : XCTestCase {
    
    fileprivate var addressBookFake : AddressBookFake!
    
    override func setUp() {
        self.addressBookFake = AddressBookFake()
        super.setUp()
    }
    
    override func tearDown() {
        self.addressBookFake = nil
        super.tearDown()
    }
}

// MARK: - Access to AB
extension AddressBookTests {

    
    func testThatItReturnsAllContactsWhenTheyHaveValidEmailAndPhoneNumbers() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com", "janet@example.com"], phoneNumbers: ["+15550100"]),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: ["siam@example.com"], phoneNumbers: ["+15550101", "+15550102"]),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 2)
        for i in 0..<self.addressBookFake.fakeContacts.count {
            XCTAssertEqual(contacts[i].emailAddresses, self.addressBookFake.fakeContacts[i].rawEmails)
            XCTAssertEqual(contacts[i].phoneNumbers, self.addressBookFake.fakeContacts[i].rawPhoneNumbers)
        }
    }
    
    func testThatItReturnsAllContactsWhenTheyHaveValidEmailOrPhoneNumbers() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: []),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: ["+15550101"]),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 2)
        for i in 0..<self.addressBookFake.fakeContacts.count {
            XCTAssertEqual(contacts[i].emailAddresses, self.addressBookFake.fakeContacts[i].rawEmails)
            XCTAssertEqual(contacts[i].phoneNumbers, self.addressBookFake.fakeContacts[i].rawPhoneNumbers)
        }
    }
    
    func testThatItFilterlContactsThatHaveNoEmailNorPhone() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: ["+15550100"]),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: []),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0].emailAddresses, self.addressBookFake.fakeContacts[0].rawEmails)
    }
}

// MARK: - Validation/normalization
extension AddressBookTests {

    func testThatItFilterlContactsThatHaveAnInvalidPhoneAndNoEmail() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: [], phoneNumbers: ["aabbccdd"]),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 0)
    }
    
    func testThatIgnoresInvalidPhones() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["janet@example.com"], phoneNumbers: ["aabbccdd"]),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0].emailAddresses, self.addressBookFake.fakeContacts[0].rawEmails)
        XCTAssertEqual(contacts[0].phoneNumbers, [])
    }
    
    func testThatItFilterlContactsThatHaveNoPhoneAndInvalidEmail() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["janet"], phoneNumbers: []),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 0)
    }
    
    func testThatIgnoresInvalidEmails() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["janet"], phoneNumbers: ["+15550103"]),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0].emailAddresses, [])
        XCTAssertEqual(contacts[0].phoneNumbers, self.addressBookFake.fakeContacts[0].rawPhoneNumbers)
    }
    
    func testThatItNormalizesPhoneNumbers() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: [], phoneNumbers: ["+1 (555) 0103"]),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0].phoneNumbers, ["+15550103"])
    }
    
    func testThatItNormalizesEmails() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["Olaf Karlsson <janet+1@example.com>"], phoneNumbers: []),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0].emailAddresses, ["janet+1@example.com"])
    }
    
    func testThatItDoesNotIgnoresPhonesWithPlusZero() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: [], phoneNumbers: ["+012345678"]),
        ]
        
        // when
        let contacts = Array(self.addressBookFake.contacts(range: 0..<100))
        
        // then
        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0].phoneNumbers, ["+012345678"])
    }
}

// MARK: - Encoding
extension AddressBookTests {
    
    func testThatItEncodesUsers() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: ["+15550101"]),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: ["+15550100"]),
            FakeAddressBookContact(firstName: "Hadiya", emailAddresses: [], phoneNumbers: ["+15550102"])
            
        ]
        let queue = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        queue.createDispatchGroups()
        let expectation = self.expectation(description: "Callback invoked")
        
        // when
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 0, maxNumberOfContacts: 100) { chunk in
            
            // then
            if let chunk = chunk {
                XCTAssertEqual(chunk.numberOfTotalContacts, 3)
                XCTAssertEqual(chunk.includedContacts, UInt(0)..<UInt(3))
                let expected = [
                    self.addressBookFake.fakeContacts[0].localIdentifier : ["BSdmiT9F5EtQrsfcGm+VC7Ofb0ZRREtCGCFw4TCimqk=",
                     "f9KRVqKI/n1886fb6FnP4oIORkG5S2HO0BoCYOxLFaA="],
                    self.addressBookFake.fakeContacts[1].localIdentifier :
                    ["YCzX+75BaI4tkCJLysNi2y8f8uK6dIfYWFyc4ibLbQA="],
                    self.addressBookFake.fakeContacts[2].localIdentifier :
                    ["iJXG3rJ3vc8rrh7EgHzbWPZsWOHFJ7mYv/MD6DlY154="]
                ]
                checkEqual(lhs: chunk.otherContactsHashes, rhs: expected)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
    }
    
    func testThatItCallsCompletionHandlerWithNilIfNoContacts() {
        
        // given
        self.addressBookFake.fakeContacts = []
        let queue = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        queue.createDispatchGroups()
        let expectation = self.expectation(description: "Callback invoked")
        
        // when
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 0, maxNumberOfContacts: 100) { chunk in
            
            // then
            XCTAssertNil(chunk)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
    }
    
    func testThatItEncodesOnlyAMaximumNumberOfUsers() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: ["+15550101"]),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: ["+15550100"]),
            FakeAddressBookContact(firstName: "Hadiya", emailAddresses: [], phoneNumbers: ["+15550102"])
            
        ]
        let queue = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        queue.createDispatchGroups()
        let expectation = self.expectation(description: "Callback invoked")
        
        // when
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 0, maxNumberOfContacts: 2) { chunk in
            
            // then
            if let chunk = chunk {
                XCTAssertEqual(chunk.numberOfTotalContacts, 3)
                XCTAssertEqual(chunk.includedContacts, UInt(0)..<UInt(2))
                let expected = [
                    self.addressBookFake.fakeContacts[0].localIdentifier : ["BSdmiT9F5EtQrsfcGm+VC7Ofb0ZRREtCGCFw4TCimqk=",
                        "f9KRVqKI/n1886fb6FnP4oIORkG5S2HO0BoCYOxLFaA="],
                    self.addressBookFake.fakeContacts[1].localIdentifier : ["YCzX+75BaI4tkCJLysNi2y8f8uK6dIfYWFyc4ibLbQA="]
                    ]
                checkEqual(lhs: chunk.otherContactsHashes, rhs: expected)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
    }
    
    func testThatItEncodesOnlyTheRequestedUsers() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: ["+15550101"]),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: ["+15550100"]),
            FakeAddressBookContact(firstName: "Hadiya", emailAddresses: [], phoneNumbers: ["+15550102"]),
            FakeAddressBookContact(firstName: " أميرة", emailAddresses: ["a@example.com"], phoneNumbers: [])
        ]
        
        let queue = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        queue.createDispatchGroups()
        let expectation = self.expectation(description: "Callback invoked")
        
        // when
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 1, maxNumberOfContacts: 2) { chunk in
            
            // then
            if let chunk = chunk {
                XCTAssertEqual(chunk.numberOfTotalContacts, 4)
                XCTAssertEqual(chunk.includedContacts, UInt(1)..<UInt(3))
                let expected = [
                    self.addressBookFake.fakeContacts[1].localIdentifier : ["YCzX+75BaI4tkCJLysNi2y8f8uK6dIfYWFyc4ibLbQA="],
                    self.addressBookFake.fakeContacts[2].localIdentifier : ["iJXG3rJ3vc8rrh7EgHzbWPZsWOHFJ7mYv/MD6DlY154="]
                    ]
                checkEqual(lhs: chunk.otherContactsHashes, rhs: expected)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
    }
    
    func testThatItEncodesAsManyContactsAsItCanIfAskedToEncodeTooMany() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: ["+15550101"]),
            FakeAddressBookContact(firstName: " أميرة", emailAddresses: ["a@example.com"], phoneNumbers: []),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: ["+15550100"]),
            FakeAddressBookContact(firstName: "Hadiya", emailAddresses: [], phoneNumbers: ["+15550102"])
        ]
        
        let queue = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        queue.createDispatchGroups()
        let expectation = self.expectation(description: "Callback invoked")
        
        // when
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 2, maxNumberOfContacts: 20) { chunk in
            
            // then
            if let chunk = chunk {
                XCTAssertEqual(chunk.numberOfTotalContacts, 4)
                XCTAssertEqual(chunk.includedContacts, UInt(2)..<UInt(4))
                let expected =  [
                    self.addressBookFake.fakeContacts[2].localIdentifier : ["YCzX+75BaI4tkCJLysNi2y8f8uK6dIfYWFyc4ibLbQA="],
                    self.addressBookFake.fakeContacts[3].localIdentifier : ["iJXG3rJ3vc8rrh7EgHzbWPZsWOHFJ7mYv/MD6DlY154="]
                    ]
                checkEqual(lhs: chunk.otherContactsHashes, rhs: expected)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
    }
    
    func testThatItEncodesNoContactIfAskedToEncodePastTheLastContact() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: ["+15550101"]),
            FakeAddressBookContact(firstName: " أميرة", emailAddresses: ["a@example.com"], phoneNumbers: []),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: ["+15550100"]),
        ]
        
        let queue = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        queue.createDispatchGroups()
        let expectation = self.expectation(description: "Callback invoked")
        
        // when
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 20, maxNumberOfContacts: 20) { chunk in
            
            // then
            if let chunk = chunk {
                XCTAssertEqual(chunk.numberOfTotalContacts, 3)
                XCTAssertEqual(chunk.includedContacts, UInt(20)..<UInt(20))
                XCTAssertEqual(chunk.otherContactsHashes.count, 0)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
    }
    
    func testThatItEncodesTheSameAddressBookInTheSameWay() {
        
        // given
        self.addressBookFake.fakeContacts = [
            FakeAddressBookContact(firstName: "Olaf", emailAddresses: ["olaf@example.com"], phoneNumbers: ["+15550101"]),
            FakeAddressBookContact(firstName: "สยาม", emailAddresses: [], phoneNumbers: ["+15550100"]),
            FakeAddressBookContact(firstName: "Hadiya", emailAddresses: [], phoneNumbers: ["+15550102"])
            
        ]
        let queue = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        queue.createDispatchGroups()
        let expectation1 = self.expectation(description: "Callback invoked once")
        
        var chunk1 : [String: [String]]? = nil
        var chunk2 : [String: [String]]? = nil
        
        // when
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 0, maxNumberOfContacts: 100) { chunk in
            
            chunk1 = chunk?.otherContactsHashes
            expectation1.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
        
        let expectation2 = self.expectation(description: "Callback invoked twice")
        self.addressBookFake.encodeWithCompletionHandler(queue, startingContactIndex: 0, maxNumberOfContacts: 100) { chunk in
            
            chunk2 = chunk?.otherContactsHashes
            expectation2.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5) { error in
            XCTAssertNil(error)
        }
        
        // then
        checkEqual(lhs: chunk1, rhs: chunk2)
    }
}


// MARK: - Helpers
private func checkEqual(lhs: [String : [String]]?, rhs: [String : [String]]?, line: UInt = #line, file : StaticString = #file) {
    guard let lhs = lhs, let rhs = rhs else {
        XCTFail("Value is nil", file: file, line: line)
        return
    }
    
    let keys1 = Set(lhs.keys)
    let keys2 = Set(rhs.keys)
    guard keys1 == keys2 else {
        XCTAssertEqual(keys1, keys2, file: file, line: line)
        return
    }
    
    for key in keys1 {
        let array1 = lhs[key]!
        let array2 = rhs[key]!
        zip(array1, array2).forEach { XCTAssertEqual($0.0, $0.1, file: file, line: line) }
    }
    
}
