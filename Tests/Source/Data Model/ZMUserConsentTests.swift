//


import XCTest
@testable import WireSyncEngine

final class ZMUserConsentTests: MessagingTest {
    var selfUser: ZMUser {
        let selfUser = ZMUser.selfUser(in: uiMOC)
        if selfUser.remoteIdentifier == nil {
            selfUser.remoteIdentifier = UUID()
        }
        return selfUser
    }
    
    func testGetRequest() {
        // given
        let request = WireSyncEngine.ConsentRequestFactory.fetchConsentRequest()
        
        // then
        XCTAssertEqual(request.method, .methodGET)
        XCTAssertEqual(request.path, "/self/consent")
        XCTAssertNil(request.payload)
    }
    
    func testSetRequest_true() {
        // given
        let request = WireSyncEngine.ConsentRequestFactory.setConsentRequest(for: .marketing, value: true)
        // then
        XCTAssertEqual(request.method, .methodPUT)
        XCTAssertEqual(request.path, "/self/consent")
        let expectedPayload: [AnyHashable: Any] = ["type": 2, "value": 1, "source": "iOS 1.0"]
        XCTAssertEqual(request.payload!.asDictionary()! as NSDictionary, expectedPayload as NSDictionary)
    }
    
    func testSetRequest_false() {
        // given
        let request = WireSyncEngine.ConsentRequestFactory.setConsentRequest(for: .marketing, value: false)
        // then
        XCTAssertEqual(request.method, .methodPUT)
        XCTAssertEqual(request.path, "/self/consent")
        let expectedPayload: [AnyHashable: Any] = ["type": 2, "value": 0, "source": "iOS 1.0"]
        XCTAssertEqual(request.payload!.asDictionary()! as NSDictionary, expectedPayload as NSDictionary)
    }
    
    func testThatItCanParseResponse() {
        typealias PayloadPair = ([String: Any], Bool)
        
        let pairs: [PayloadPair] =
            [(["results": [["type": "yobobo", "value": 1]]], false),
             (["results": [["type": 2, "value": 1]]], true),
             (["results": [["type": 2, "value": 0]]], false),
             (["results": [["type": 1, "value": 1]]], false),
             (["results": [["type": 1000, "value": 0], ["type": 2, "value": 1]]], true),
             (["results": []], false),
             ([:], false)]
            
            pairs.forEach {
                let payload = ZMUser.parse(consentPayload: $0.0 as ZMTransportData)
                
                let value = payload[.marketing] ?? false
                XCTAssertEqual(value, $0.1)
            }
    }
    
    func testThatItCanFetchState() {
        // given
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/self/consent" else { return nil }
            
            return ZMTransportResponse(payload: ["results": [["type": 2, "value": 1]]] as ZMTransportData, httpStatus: 200, transportSessionError: nil)
        }
        
        let fetchedData = expectation(description: "fetched data")
        
        // when
        
        selfUser.fetchMarketingConsent(in: mockUserSession) { result in
            switch result {
            case .failure(_):
                XCTFail()
            case .success(let result):
                XCTAssertTrue(result)
                fetchedData.fulfill()
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatItFailsOnInvalidOperation_get() {
        // given
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/self/consent" else { return nil }
            
            return ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
        }
        
        let receivedError = expectation(description: "received error")
        // when
        
        selfUser.fetchMarketingConsent(in: mockUserSession) { result in
            switch result {
            case .failure(let error):
                XCTAssertEqual(error as! WireSyncEngine.ConsentRequestError, WireSyncEngine.ConsentRequestError.unknown)
                receivedError.fulfill()
            case .success(_):
                XCTFail()
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatItCanSetTheState() {
        // given
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/self/consent" else { return nil }
            
            return ZMTransportResponse(payload: nil, httpStatus: 200, transportSessionError: nil)
        }
        
        let successExpectation = expectation(description: "set is successful")
        // when
        
        selfUser.setMarketingConsent(to: true, in: self.mockUserSession) { result in
            switch result {
            case .failure(_):
                XCTFail()
            case .success:
                successExpectation.fulfill()
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
    
    func testThatItFailsOnInvalidOperation_set() {
        // given
        mockTransportSession.responseGeneratorBlock = { request in
            guard request.path == "/self/consent" else { return nil }
            
            return ZMTransportResponse(payload: ["label": "invalid-op"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
        }
        
        let receivedError = expectation(description: "received error")
        // when
        
        selfUser.setMarketingConsent(to: true, in: self.mockUserSession) { result in
            switch result {
            case .failure(let error):
                XCTAssertEqual(error as! WireSyncEngine.ConsentRequestError, WireSyncEngine.ConsentRequestError.unknown)
                receivedError.fulfill()
            case .success:
                XCTFail()
            }
        }
        
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        mockTransportSession.responseGeneratorBlock = nil
        mockTransportSession.resetReceivedRequests()
    }
}
