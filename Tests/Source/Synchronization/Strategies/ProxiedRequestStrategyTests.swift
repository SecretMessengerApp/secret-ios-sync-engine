// 


import Foundation
import WireSyncEngine

class ProxiedRequestStrategyTests: MessagingTest {

    fileprivate var sut : ProxiedRequestStrategy!
    fileprivate var requestsStatus : ProxiedRequestsStatus!
    fileprivate var mockApplicationStatus : MockApplicationStatus!

    override func setUp() {
        super.setUp()
        self.requestsStatus = ProxiedRequestsStatus(requestCancellation: MockRequestCancellation())
        self.mockApplicationStatus = MockApplicationStatus()
        self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
        self.sut = ProxiedRequestStrategy(withManagedObjectContext: self.uiMOC, applicationStatus: self.mockApplicationStatus, requestsStatus: self.requestsStatus)
    }
    
    override func tearDown() {
        self.sut = nil
        self.requestsStatus = nil
        super.tearDown()
    }
    
    func testThatItGeneratesNoRequestsIfTheStatusIsEmpty() {
        XCTAssertNil(self.sut.nextRequest())
    }
    
    func testThatItGeneratesAGiphyRequest() {
    
        
        
        // given
        requestsStatus.add(request: ProxyRequest(type: .giphy, path: "/foo/bar", method:.methodGET, callback: { (_,_,_) -> Void in return}))
        
        // when
        let request : ZMTransportRequest? = self.sut.nextRequest()
        
        // then
        if let request = request {
            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodGET)
            XCTAssertEqual(request.path, "/proxy/giphy/foo/bar")
            XCTAssertTrue(request.needsAuthentication)
        } else {
            XCTFail("Empty request")
        }
    }

    func testThatItGeneratesASoundcloudRequest() {

        // given
        requestsStatus.add(request: ProxyRequest(type: .soundcloud, path: "/foo/bar", method:.methodGET, callback: { (_,_,_) -> Void in return}))
        
        // when
        let request : ZMTransportRequest? = self.sut.nextRequest()
        
        // then
        if let request = request {
            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodGET)
            XCTAssertEqual(request.path, "/proxy/soundcloud/foo/bar")
            XCTAssertTrue(request.needsAuthentication)
            XCTAssertTrue(request.doesNotFollowRedirects)
        } else {
            XCTFail("Empty request")
        }
    }

    func testThatItGeneratesAYouTubeRequest() {

        // given
        requestsStatus.add(request: ProxyRequest(type: .youTube, path: "/foo/bar", method:.methodGET, callback: { (_,_,_) -> Void in return}))

        // when
        let request : ZMTransportRequest? = self.sut.nextRequest()

        // then
        if let request = request {
            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodGET)
            XCTAssertEqual(request.path, "/proxy/youtube/foo/bar")
            XCTAssertTrue(request.needsAuthentication)
        } else {
            XCTFail("Empty request")
        }
    }
    
    func testThatItGeneratesARequestOnlyOnce() {
        
        // given
        requestsStatus.add(request: ProxyRequest(type: .giphy, path: "/foo/bar1", method:.methodGET, callback: { (_,_,_) -> Void in return}))
        
        // when
        let request1 : ZMTransportRequest? = self.sut.nextRequest()
        let request2 : ZMTransportRequest? = self.sut.nextRequest()
        
        // then
        XCTAssertNotNil(request1)
        XCTAssertNil(request2)

    }
    
    func testThatItCallsTheCompletionHandlerWhenTheRequestIsCompleted() {
        
        // given
        let error = NSError(domain: "ZMTransportSession", code: 10, userInfo: nil)
        let data = "Foobar".data(using: String.Encoding.utf8, allowLossyConversion: true)!
        let HTTPResponse = HTTPURLResponse(url: URL(string: "http://www.example.com/")!, statusCode:200, httpVersion:"HTTP/1.1", headerFields:[
                "Content-Length": "\(data.count)",
                "Server": "nginx"
            ]
        )!
        
        let response = ZMTransportResponse(httpurlResponse: HTTPResponse, data: data, error: error)
        let expectation = self.expectation(description: "Callback invoked")

        requestsStatus.add(request: ProxyRequest(type: .giphy, path: "/foo/bar1", method:.methodGET, callback: {
            responseData,responseURLResponse,responseError in
            XCTAssertEqual(data, responseData)
            XCTAssertEqual(error, responseError)
            XCTAssertEqual(HTTPResponse, responseURLResponse)
            expectation.fulfill()
            
            return
        }))

        
        // when
        let request : ZMTransportRequest? = self.sut.nextRequest()
        if let request = request {
            request.complete(with: response)
        }
        
        // then
        self.spinMainQueue(withTimeout: 0.2)
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatItMakesTheRequestExpireAfter20Seconds() {
        
        // given
        let ExpectedDelay : TimeInterval = 20
        requestsStatus.add(request: ProxyRequest(type: .giphy, path: "/foo/bar1", method:.methodGET, callback: { (_,_,_) -> Void in return}))
        
        // when
        let request : ZMTransportRequest? = self.sut.nextRequest()
        
        // then
        if let request = request {
            XCTAssertNotNil(request.expirationDate)
            let delay = request.expirationDate!.timeIntervalSinceNow
            XCTAssertLessThanOrEqual(delay, ExpectedDelay)
            XCTAssertGreaterThanOrEqual(delay, ExpectedDelay - 3)
            
        } else {
            XCTFail("Empty request")
        }
    }
    
    func testThatItUpdateTheRequestStatusWhenTaskIsCreated() {
        
        // given
        let proxyRequest = ProxyRequest(type: .giphy, path: "/foo/bar1", method:.methodGET, callback: { (_,_,_) -> Void in return})
        requestsStatus.add(request: proxyRequest)
        let request : ZMTransportRequest? = self.sut.nextRequest()
        
        // when
        request?.callTaskCreationHandlers(withIdentifier: 1, sessionIdentifier: "123")
        
        // then
        self.spinMainQueue(withTimeout: 0.2)
        let (executedRequest, taskIdentifier) = requestsStatus.executedRequests.first!
        XCTAssertEqual(proxyRequest, executedRequest)
        XCTAssertEqual(taskIdentifier.identifier, 1)
        XCTAssertEqual(taskIdentifier.sessionIdentifier, "123")
        
    }
}
