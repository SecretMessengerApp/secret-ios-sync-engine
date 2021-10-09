//

import XCTest
@testable import WireSyncEngine

class CompanyLoginRequestDetectorTests: XCTestCase {

    var pasteboard: MockPasteboard!
    var detector: CompanyLoginRequestDetector!

    override func setUp() {
        super.setUp()
        pasteboard = MockPasteboard()
        detector = CompanyLoginRequestDetector(pasteboard: pasteboard)
    }

    override func tearDown() {
        detector = nil
        pasteboard = nil
        super.tearDown()
    }

    func testThatItDetectsValidWireCode_Uppercase() {
        // GIVEN
        pasteboard.text = "wire-46A17D7F-2351-495E-AEDA-E7C96AC74994"

        // WHEN
        var detectedCode: String?
        let detectionExpectation = expectation(description: "Detector returns a result")

        detector.detectCopiedRequestCode {
            detectedCode = $0?.code
            detectionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        // THEN
        XCTAssertEqual(detectedCode, "wire-46A17D7F-2351-495E-AEDA-E7C96AC74994")
    }

    func testThatItDetectsValidWireCode_Lowercase() {
        // GIVEN
        pasteboard.text = "wire-70488875-13dd-4ba7-9636-a983e1831f5f"

        // WHEN
        var detectedCode: String?
        let detectionExpectation = expectation(description: "Detector returns a result")

        detector.detectCopiedRequestCode {
            detectedCode = $0?.code
            detectionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        // THEN
        XCTAssertEqual(detectedCode, "wire-70488875-13DD-4BA7-9636-A983E1831F5F")
    }

    func testThatItDetectsCodeInComplexText() {
        // GIVEN
        pasteboard.text = """
        <html>
            This is your code: ohwowwire-A6AAA905-E42D-4220-A455-CFE8822DB690&nbsp;
        </html>
        """

        // WHEN
        var detectedCode: String?
        let detectionExpectation = expectation(description: "Detector returns a result")

        detector.detectCopiedRequestCode {
            detectedCode = $0?.code
            detectionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)


        // THEN
        XCTAssertEqual(detectedCode, "wire-A6AAA905-E42D-4220-A455-CFE8822DB690")
    }

    func testThatItDetectsValidCode_UserInput() {
        // GIVEN
        let text = "wire-81DD91BA-B3D0-46F0-BC29-E491938F0A54"

        // WHEN
        let isDetectedCodeValid = CompanyLoginRequestDetector.isValidRequestCode(in: text)

        // THEN
        XCTAssertTrue(isDetectedCodeValid)
    }

    func testThatItDetectsInvalidCode_MissingPrefix() {
        // GIVEN
        pasteboard.text = "8FBF187C-2039-409B-B16F-5FCF485514E1"

        // WHEN
        var detectedCode: String?
        let detectionExpectation = expectation(description: "Detector returns a result")

        detector.detectCopiedRequestCode {
            detectedCode = $0?.code
            detectionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        // THEN
        XCTAssertNil(detectedCode)
    }

    func testThatItDetectsInvalidCode_WrongUUIDFormat() {
        // GIVEN
        pasteboard.text = "wire-D82916EA"

        // WHEN
        var detectedCode: String?
        let detectionExpectation = expectation(description: "Detector returns a result")

        detector.detectCopiedRequestCode {
            detectedCode = $0?.code
            detectionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        // THEN
        XCTAssertNil(detectedCode)
    }

    func testThatItFailsWhenPasteboardIsEmpty() {
        // GIVEN
        pasteboard.text = nil

        // WHEN
        var detectedCode: String?
        let detectionExpectation = expectation(description: "Detector returns a result")

        detector.detectCopiedRequestCode {
            detectedCode = $0?.code
            detectionExpectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        // THEN
        XCTAssertNil(detectedCode)
    }
    
    func testThatItSetsIsNewOnTheResultIfTheChangeCountIncreased() {
        // GIVEN
        let code = "wire-81DD91BA-B3D0-46F0-BC29-E491938F0A54"
        pasteboard.text = code
        pasteboard.changeCount = 41
        
        do {
            let detectionExpectation = expectation(description: "Detector returns a result")
            
            detector.detectCopiedRequestCode {
                XCTAssertEqual($0?.isNew, true)
                XCTAssertEqual($0?.code, code)
                detectionExpectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }

        do {
            let detectionExpectation = expectation(description: "Detector returns a result")
            
            detector.detectCopiedRequestCode {
                XCTAssertEqual($0?.isNew, false)
                XCTAssertEqual($0?.code, code)
                detectionExpectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }

        // WHEN
        pasteboard.changeCount = 42
        
        // THEN
        do {
            let detectionExpectation = expectation(description: "Detector returns a result")
            
            detector.detectCopiedRequestCode {
                XCTAssertEqual($0?.isNew, true)
                XCTAssertEqual($0?.code, code)
                detectionExpectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }
    }
    
    func testThatItDoesNotSetIsNewOnTheResultIfTheChangeCountDidNotIncrease() {
        // GIVEN
        let code = "wire-81DD91BA-B3D0-46F0-BC29-E491938F0A54"
        pasteboard.text = code
        pasteboard.changeCount = 42
        
        // WHEN
        do {
            let detectionExpectation = expectation(description: "Detector returns a result")
            
            detector.detectCopiedRequestCode {
                XCTAssertEqual($0?.isNew, true)
                XCTAssertEqual($0?.code, code)
                detectionExpectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        // WHEN
        do {
            let detectionExpectation = expectation(description: "Detector returns a result")
            
            detector.detectCopiedRequestCode {
                XCTAssertEqual($0?.isNew, false)
                XCTAssertEqual($0?.code, code)
                detectionExpectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        // THEN
        do {
            let detectionExpectation = expectation(description: "Detector returns a result")
            
            detector.detectCopiedRequestCode {
                XCTAssertEqual($0?.isNew, false)
                XCTAssertEqual($0?.code, code)
                detectionExpectation.fulfill()
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }
    }

}
