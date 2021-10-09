////

import XCTest

class ZMAuthenticationStatusTests_PhoneVerification: XCTestCase {
    
    var sut: ZMAuthenticationStatus!
    var userInfoParser: MockUserInfoParser!
    
    override func setUp() {
        super.setUp()
        
        userInfoParser = MockUserInfoParser()
        let groupQueue = DispatchGroupQueue(queue: DispatchQueue.main)
        sut = ZMAuthenticationStatus(groupQueue: groupQueue, userInfoParser: userInfoParser)
    }
    
    func testThatItCanRequestPhoneVerificationCodeForLoginAfterRequestingTheCode() {
    
        // given
        let originalPhone = "+49(123)45678900"
        var phone: Any? = originalPhone
        _ = try? ZMPhoneNumberValidator.validateValue(&phone)
        
        // when
        sut.prepareForRequestingPhoneVerificationCode(forLogin: originalPhone)
        
        // then
        XCTAssertEqual(sut.currentPhase, .requestPhoneVerificationCodeForLogin)
        XCTAssertEqual(sut.loginPhoneNumberThatNeedsAValidationCode, phone as? String)
        XCTAssertNotEqual(originalPhone, phone as? String, "Should not have changed original phone")
        
        
    }
}
