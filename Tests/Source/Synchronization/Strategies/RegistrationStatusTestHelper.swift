//

import Foundation
@testable import WireSyncEngine

class TestRegistrationStatus: WireSyncEngine.RegistrationStatusProtocol {
    var handleErrorCalled = 0
    var handleErrorError: Error?
    func handleError(_ error: Error) {
        handleErrorCalled += 1
        handleErrorError = error
    }

    var successCalled = 0
    func success() {
        successCalled += 1
    }

    var phase: RegistrationPhase = .none
}

protocol RegistrationStatusStrategyTestHelper {
    var registrationStatus: TestRegistrationStatus! { get }
    func handleResponse(response: ZMTransportResponse)
}

extension RegistrationStatusStrategyTestHelper {
    func checkResponseError(with phase: RegistrationPhase, code: ZMUserSessionErrorCode, errorLabel: String, httpStatus: NSInteger, file: StaticString = #file, line: UInt = #line) {
        registrationStatus.phase = phase

        let expectedError = NSError(code: code, userInfo: [:])
        let payload = [
            "label": errorLabel,
            "message":"some"
        ]

        let response = ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: httpStatus, transportSessionError: nil)

        // when
        XCTAssertEqual(registrationStatus.successCalled, 0, "Success should not be called", file: file, line: line)
        XCTAssertEqual(registrationStatus.handleErrorCalled, 0, "HandleError should not be called", file: file, line: line)
        handleResponse(response: response)

        // then
        XCTAssertEqual(registrationStatus.successCalled, 0, "Success should not be called", file: file, line: line)
        XCTAssertEqual(registrationStatus.handleErrorCalled, 1, "HandleError should be called", file: file, line: line)
        XCTAssertEqual(registrationStatus.handleErrorError as NSError?, expectedError, "HandleError should be called with error: \(expectedError), but was \(registrationStatus.handleErrorError?.localizedDescription ?? "nil")", file: file, line: line)
    }
}
