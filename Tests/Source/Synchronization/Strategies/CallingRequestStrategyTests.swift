//

import Foundation
import WireRequestStrategy

class CallingRequestStrategyTests : MessagingTest {

    var sut: CallingRequestStrategy!
    var mockRegistrationDelegate : ClientRegistrationDelegate!
    
    override func setUp() {
        super.setUp()
        mockRegistrationDelegate = MockClientRegistrationDelegate()
        sut = CallingRequestStrategy(managedObjectContext: uiMOC, clientRegistrationDelegate: mockRegistrationDelegate, flowManager: FlowManagerMock(), callEventStatus: CallEventStatus())
    }
    
    override func tearDown() {
        sut = nil
        mockRegistrationDelegate = nil
        super.tearDown()
    }
    
    func testThatItReturnsItselfAndTheGenericMessageStrategyAsContextChangeTracker(){
        // when
        let trackers = sut.contextChangeTrackers
        
        // then
        XCTAssertTrue(trackers.first is CallingRequestStrategy)
        XCTAssertTrue(trackers.last is GenericMessageRequestStrategy)
    }
    
    func testThatItGenerateCallConfigRequestAndCallsTheCompletionHandler() {
        
        // given
        let expectedCallConfig = "{\"config\":true}"
        let receivedCallConfigExpectation = expectation(description: "Received CallConfig")
        
        sut.requestCallConfig { (callConfig, httpStatusCode) in
            if callConfig == expectedCallConfig, httpStatusCode == 200 {
                receivedCallConfigExpectation.fulfill()
            }
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let request = sut.nextRequest()
        XCTAssertEqual(request?.path, "/calls/config/v2")
        
        // when
        let payload = [ "config" : true ]
        request?.complete(with: ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil))
        
        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatItGeneratesOnlyOneCallConfigRequest() {
        
        // given
        sut.requestCallConfig { (_, _) in}
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        let request = sut.nextRequest()
        XCTAssertNotNil(request)
        
        // then
        let secondRequest = sut.nextRequest()
        XCTAssertNil(secondRequest)
    }
    
    func testThatItGeneratesCompressedCallConfigRequest() {
        
        // given
        sut.requestCallConfig { (_, _) in}
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        
        // then
        XCTAssertTrue(request.shouldCompress)
    }
    
    func testThatItDoesNotForwardUnsuccessfulResponses() {
        // given
        let expectedCallConfig = "{\"config\":true}"
        let receivedCallConfigExpectation = expectation(description: "Received CallConfig")
        
        sut.requestCallConfig { (callConfig, httpStatusCode) in
            if callConfig == expectedCallConfig, httpStatusCode == 200 {
                receivedCallConfigExpectation.fulfill()
            } else {
                XCTFail()
            }
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let request = sut.nextRequest()
        XCTAssertEqual(request?.path, "/calls/config/v2")
        
        // when
        let badPayload = [ "error" : "not found" ]
        request?.complete(with: ZMTransportResponse(payload: badPayload as ZMTransportData, httpStatus: 412, transportSessionError: nil))
        
        // when
        let payload = [ "config" : true ]
        request?.complete(with: ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil))

        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))

    }
}
