//


import XCTest


class MockRequestCancellation : NSObject, ZMRequestCancellation {
    
    var canceledTasks : [ZMTaskIdentifier] = []
    
    func cancelTask(with taskIdentifier: ZMTaskIdentifier) {
        canceledTasks.append(taskIdentifier)
    }
}

class ProxiedRequestsStatusTests: MessagingTest {
    
    fileprivate var sut: ProxiedRequestsStatus!
    fileprivate var mockRequestCancellation : MockRequestCancellation!
    
    override func setUp() {
        super.setUp()
        self.mockRequestCancellation = MockRequestCancellation()
        self.sut = ProxiedRequestsStatus(requestCancellation: mockRequestCancellation)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testThatRequestIsAddedToPendingRequest() {
        //given
        let request = ProxyRequest(type: .giphy, path: "foo/bar", method: .methodGET, callback: nil)
        
        //when
        self.sut.add(request: request)
        
        //then
        let pendingRequest = self.sut.pendingRequests.first
        XCTAssertEqual(pendingRequest, request)
    }
    
    func testCancelRemovesRequestFromPendingRequests() {
        // given
        let request = ProxyRequest(type: .giphy, path: "foo/bar", method: .methodGET, callback: nil)
        sut.add(request: request)
        
        // when
        sut.cancel(request: request)
        
        // then
        XCTAssertTrue(sut.pendingRequests.isEmpty)
    }
    
    func testCancelCancelsAssociatedDataTask() {
        // given
        let request = ProxyRequest(type: .giphy, path: "foo/bar", method: .methodGET, callback: nil)
        let taskIdentifier = ZMTaskIdentifier(identifier: 0, sessionIdentifier: "123")!
        sut.executedRequests[request] = taskIdentifier

        // when
        sut.cancel(request: request)
        
        // then
        XCTAssertEqual(mockRequestCancellation.canceledTasks.first, taskIdentifier)
    }
    
}


