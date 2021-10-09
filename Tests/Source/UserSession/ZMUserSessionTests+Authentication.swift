////

import Foundation

class ZMUserSessionTests_Authentication: ZMUserSessionTestsBase {
    
    func testThatItEnqueuesRequestToDeleteTheSelfClient() {
        // given
        let selfClient = createSelfClient()
        let credentials = ZMEmailCredentials(email: "john.doe@domain.com", password: "123456")
        
        // when
        sut.logout(credentials: credentials, {_ in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let request = lastEnqueuedRequest!
        let payload = request.payload as? [String: Any]
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodDELETE)
        XCTAssertEqual(request.path, "/clients/\(selfClient.remoteIdentifier!)")
        XCTAssertEqual(payload?["password"] as? String, credentials.password)
    }
    
    func testThatItEnqueuesRequestToDeleteTheSelfClientWithoutPassword() {
        // given
        let selfClient = createSelfClient()
        let credentials = ZMEmailCredentials(email: "john.doe@domain.com", password: "")
        
        // when
        sut.logout(credentials: credentials, {_ in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let request = lastEnqueuedRequest!
        let payload = request.payload as? [String: Any]
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodDELETE)
        XCTAssertEqual(request.path, "/clients/\(selfClient.remoteIdentifier!)")
        XCTAssertEqual(payload?.keys.count, 0)
    }
    
    func testThatItPostsNotification_WhenLogoutRequestSucceeds() {
        // given
        let recorder = PostLoginAuthenticationNotificationRecorder(managedObjectContext: uiMOC)
        let credentials = ZMEmailCredentials(email: "john.doe@domain.com", password: "123456")
        _ = createSelfClient()
        
        // when
        sut.logout(credentials: credentials, {_ in })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        lastEnqueuedRequest?.complete(with: ZMTransportResponse(payload: nil, httpStatus: 200, transportSessionError: nil))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(recorder.notifications.count, 1)
        let event = recorder.notifications.last
        XCTAssertEqual(event?.event, .userDidLogout)
        XCTAssertEqual(event?.accountId, ZMUser.selfUser(in: uiMOC).remoteIdentifier)
    }
    
    func testThatItCallsTheCompletionHandler_WhenLogoutRequestSucceeds() {
        // given
        let credentials = ZMEmailCredentials(email: "john.doe@domain.com", password: "123456")
        _ = createSelfClient()
        
        // expect
        let completionHandlerCalled = expectation(description: "Completion handler called")
        
        // when
        sut.logout(credentials: credentials, {result in
            switch result {
            case .success:
                completionHandlerCalled.fulfill()
            case .failure(_):
                XCTFail()
            }
        })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        lastEnqueuedRequest?.complete(with: ZMTransportResponse(payload: nil, httpStatus: 200, transportSessionError: nil))
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
        
    func testThatItCallsTheCompletionHandlerWithCorrectErrorCode_WhenLogoutRequestFails() {
        checkThatItCallsTheCompletionHandler(with: .clientDeletedRemotely, for: ZMTransportResponse(payload: ["label": "client-not-found"] as ZMTransportData, httpStatus: 404, transportSessionError: nil))
        checkThatItCallsTheCompletionHandler(with: .invalidCredentials, for: ZMTransportResponse(payload: ["label": "invalid-credentials"] as ZMTransportData, httpStatus: 403, transportSessionError: nil))
        checkThatItCallsTheCompletionHandler(with: .invalidCredentials, for: ZMTransportResponse(payload: ["label": "missing-auth"]  as ZMTransportData, httpStatus: 403, transportSessionError: nil))
        checkThatItCallsTheCompletionHandler(with: .invalidCredentials, for: ZMTransportResponse(payload: ["label": "bad-request"]  as ZMTransportData, httpStatus: 403, transportSessionError: nil))
    }
    
    func checkThatItCallsTheCompletionHandler(with errorCode: ZMUserSessionErrorCode, for response: ZMTransportResponse) {
        // given
        let credentials = ZMEmailCredentials(email: "john.doe@domain.com", password: "123456")
        _ = createSelfClient()
        
        // expect
        let completionHandlerCalled = expectation(description: "Completion handler called")
        
        // when
        sut.logout(credentials: credentials, {result in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                if errorCode == (error as NSError).userSessionErrorCode {
                    completionHandlerCalled.fulfill()
                }
                
            }
        })
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        lastEnqueuedRequest?.complete(with: response)
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
}
