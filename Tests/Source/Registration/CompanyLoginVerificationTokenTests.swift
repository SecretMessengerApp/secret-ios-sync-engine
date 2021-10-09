//

import XCTest
@testable import WireSyncEngine

class CompanyLoginVerificationTokenTests: XCTestCase {
    
    var defaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: name)!
    }
    
    override func tearDown() {
        CompanyLoginVerificationToken.flush(in: defaults)
        defaults = nil
        super.tearDown()
    }
    
    func testThatItCanStoreAndRetrieveAToken() {
        // Given
        let token = CompanyLoginVerificationToken()
        
        // When
        XCTAssert(token.store(in: defaults))
        
        // Then
        let retrieved = CompanyLoginVerificationToken.current(in: defaults)
        XCTAssertEqual(token, retrieved)
    }
    
    func testThatItDoesNotFlushAValidToken() {
        // Given
        let token = CompanyLoginVerificationToken()
        XCTAssert(token.store(in: defaults))
        XCTAssertFalse(token.isExpired)
        
        XCTAssertNotNil(CompanyLoginVerificationToken.current(in: defaults))
        
        // When
        CompanyLoginVerificationToken.flushIfNeeded(in: defaults)
        
        // Then
        let retrieved = CompanyLoginVerificationToken.current(in: defaults)
        XCTAssertEqual(token, retrieved)
    }
    
    func testThatItDoesFlushAnInvalidToken() {
        // Given
        let token = CompanyLoginVerificationToken(creationDate: .distantPast)
        XCTAssert(token.isExpired)

        XCTAssert(token.store(in: defaults))
        XCTAssertNotNil(CompanyLoginVerificationToken.current(in: defaults))
        
        // When
        CompanyLoginVerificationToken.flushIfNeeded(in: defaults)
        
        // Then
        let retrieved = CompanyLoginVerificationToken.current(in: defaults)
        XCTAssertNil(retrieved)
    }
    
    func testThatItMatchesAnIdentifierWhileValid() {
        // Given
        let uuid = UUID.create()
        let token = CompanyLoginVerificationToken(uuid: uuid)
        
        // When & Then
        XCTAssert(token.matches(identifier: uuid))
        XCTAssertFalse(token.matches(identifier: .create()))
    }
    
    func testThatItDoesNotMatchAnIdentifierWhenExpired() {
        // Given
        let uuid = UUID.create()
        let token = CompanyLoginVerificationToken(uuid: uuid, creationDate: .distantPast)
        XCTAssert(token.isExpired)
        
        // When & Then
        XCTAssertFalse(token.matches(identifier: uuid))
        XCTAssertFalse(token.matches(identifier: .create()))
    }
    
}
