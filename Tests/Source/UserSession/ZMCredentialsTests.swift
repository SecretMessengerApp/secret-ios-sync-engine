//
import WireUtilities

class ZMCredentialTests: MessagingTest {

    func testThatItStoresPhoneCredentials() {
        let phoneNumber = "+4912345678"
        let code = "aabbcc"
        
        let sut = ZMPhoneCredentials(phoneNumber: phoneNumber, verificationCode: code)
        
        XCTAssertEqual(sut.phoneNumber, phoneNumber)
        XCTAssertEqual(sut.phoneNumberVerificationCode, code)
        
    }
    
    func testThatItNormalizesThePhoneNumber() {
        let originalPhoneNumber = "+49(123)45.6-78"
        var phone: Any? = originalPhoneNumber
    
        _ = try? ZMPhoneNumberValidator.validateValue(&phone)
        
        let code = "aabbcc"
        
        let sut = ZMPhoneCredentials(phoneNumber: phone as! String, verificationCode: code)
        
        XCTAssertEqual(sut.phoneNumber, phone as? String)
        XCTAssertEqual(sut.phoneNumberVerificationCode, code)
        XCTAssertNotEqual(phone as? String, originalPhoneNumber, "Should not have modified original")
    }
}
