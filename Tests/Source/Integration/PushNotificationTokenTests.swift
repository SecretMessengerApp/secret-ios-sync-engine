////

import Foundation
@testable import WireSyncEngine
import WireMockTransport

class PushNotificationTokenTests: IntegrationTest {

    enum TokenRequest {
        case get
        case post(Data)
        case delete(Data)
    }

    func check(request: ZMTransportRequest, expectedRequest: TokenRequest, line: UInt = #line) {
        switch expectedRequest {
        case .get:
            XCTAssertEqual(request.method, .methodGET, "Should be GET '/push/tokens', found \(request)", line: line)
        case .delete(let data):
            XCTAssertEqual(request.method, .methodDELETE, "Should be DELETE '/push/tokens', found \(request)", line: line)
            XCTAssertEqual(request.path, "/push/tokens/\(data.zmHexEncodedString())", "Should be DELETE '/push/tokens/\(data.zmHexEncodedString())', found \(request)", line: line)
        case .post(let data):
            XCTAssertEqual(request.method, .methodPOST, "Should be POST '/push/tokens', found \(request)", line: line)

            guard let payload = request.payload?.asDictionary() as? [String : String] else { return XCTFail("No payload found: \(request)", line: line) }
            guard payload["transport"] == "APNS_VOIP" else { return XCTFail("Not VOIP transport: \(request)", line: line) }
            guard payload["token"] == data.zmHexEncodedString() else {
                return XCTFail("Wrong device token: \(request)", line: line)

            }
        }
    }

    func checkThatLastRequestContainsTokenRequests(_ requests: [TokenRequest], line: UInt = #line) {
        let tokenRequests = mockTransportSession.receivedRequests()
            .filter { $0.path.hasPrefix("/push/tokens")}
        if tokenRequests.count == requests.count {
            for (request, expectedRequest) in zip(tokenRequests, requests) {
                check(request: request, expectedRequest: expectedRequest, line: line)
            }
        } else if tokenRequests.isEmpty {
            XCTFail("No token requests found", line: line)
        } else {
            XCTFail("Wrong number of token requests, expected \(requests.count), found \(tokenRequests.count)", line: line)
        }
    }

    func checkThatLastRequestContainsTokenRequest(_ request: TokenRequest, line: UInt = #line) {
        checkThatLastRequestContainsTokenRequests([request], line: line)
    }

    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
    }

    func testThatItRegistersPushToken() {
        XCTAssert(login())

        // given
        let token = Data(repeating: 0x41, count: 10)

        // when
        userSession?.setPushKitToken(token)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        checkThatLastRequestContainsTokenRequest(.post(token))
    }

    func testThatItDoesNotReRegisterSamePushToken() {
        XCTAssert(login())

        // given
        let token = Data(repeating: 0x41, count: 10)
        userSession?.setPushKitToken(token)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mockTransportSession.resetReceivedRequests()

        // when
        userSession?.setPushKitToken(token)

        // then
        XCTAssertTrue(mockTransportSession.receivedRequests().isEmpty)
    }

    func testThatItRegistersUpdatedPushToken() {
        XCTAssert(login())

        // given
        let token = Data(repeating: 0x41, count: 10)
        userSession?.setPushKitToken(token)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mockTransportSession.resetReceivedRequests()

        // when
        let otherToken = Data(repeating: 0x42, count: 10)
        userSession?.setPushKitToken(otherToken)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        checkThatLastRequestContainsTokenRequest(.post(otherToken))
    }

    func testThatItDeletesTokenWhenMarkedAsToBeDeleted() {
        XCTAssert(login())

        // given
        let token = Data(repeating: 0x41, count: 10)
        userSession?.setPushKitToken(token)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mockTransportSession.resetReceivedRequests()

        // when
        userSession?.deletePushKitToken()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        checkThatLastRequestContainsTokenRequest(.delete(token))
        XCTAssertNil(userSession?.selfUserClient().pushToken)
    }

    func testThatItDoesNotDeleteTokenIfItWasResetWhileRequestIsInProgress() {
        XCTAssert(login())

        // given
        let token = Data(repeating: 0x41, count: 10)
        let otherToken = Data(repeating: 0x42, count: 10)
        userSession?.setPushKitToken(token)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mockTransportSession.resetReceivedRequests()

        // when
        userSession?.deletePushKitToken()
        userSession?.setPushKitToken(otherToken)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        checkThatLastRequestContainsTokenRequest(.post(otherToken))
        guard let pushToken = userSession?.selfUserClient().pushToken else { return XCTFail("Push token should be set") }
        XCTAssertEqual(pushToken.deviceToken, otherToken)
        XCTAssertFalse(pushToken.isMarkedForDeletion)
    }

    func overrideBackendToken(of token: Data, with updatedToken: Data, line: UInt = #line) {
        guard var payload = mockTransportSession.pushTokens[token.zmHexEncodedString()] else { return XCTFail(line: line) }
        payload["token"] = updatedToken.zmHexEncodedString()
        mockTransportSession.addPushToken(token.zmHexEncodedString(), payload: payload)
    }

    func testThatItValidatesTheTokenAndDoesNotUploadIfTheLocalOneIsTheSame() {
        XCTAssert(login())

        // given
        let token = Data(repeating: 0x41, count: 10)
        pushRegistry.mockPushToken = token
        userSession?.setPushKitToken(token)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mockTransportSession.resetReceivedRequests()
        guard let client = userSession?.selfUserClient() else { return XCTFail() }
        guard let pushToken = client.pushToken else { return XCTFail() }

        // when
        userSession?.validatePushToken()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 55.5))

        // then
        checkThatLastRequestContainsTokenRequests([.get])
        guard let afterUpdate = userSession?.selfUserClient().pushToken else { return XCTFail("Push token should be set") }
        XCTAssertEqual(pushToken, afterUpdate)
    }

    func testThatItValidatesTheTokenAndUploadsTheLocalOneIfOnTheServerItIsDifferent() {
        XCTAssert(login())

        // given
        let token = Data(repeating: 0x41, count: 10)
        pushRegistry.mockPushToken = token
        userSession?.setPushKitToken(token)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mockTransportSession.resetReceivedRequests()
        guard let client = userSession?.selfUserClient() else { return XCTFail() }
        guard let pushToken = client.pushToken else { return XCTFail() }

        // when
        // Change the registered push token on the backend
        overrideBackendToken(of: token, with: Data(repeating: 0xAA, count: 10))
        userSession?.validatePushToken()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 55.5))

        // then
        checkThatLastRequestContainsTokenRequests([.get, .post(token)])
        guard let afterUpdate = userSession?.selfUserClient().pushToken else { return XCTFail("Push token should be set") }
        XCTAssertEqual(pushToken, afterUpdate)
    }
}
