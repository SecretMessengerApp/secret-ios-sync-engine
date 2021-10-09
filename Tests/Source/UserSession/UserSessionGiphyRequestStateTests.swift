//


import XCTest

class UserSessionGiphyRequestStateTests: ZMUserSessionTestsBase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testThatMakingRequestAddsPendingRequest() {
        
        //given
        let path = "foo/bar"
        let url = URL(string: path, relativeTo: nil)!
        
        let exp = self.expectation(description: "expected callback")
        let callback: (Data?, HTTPURLResponse?, Error?) -> Void = { (_, _, _) -> Void in
            exp.fulfill()
        }
        
        //when
        self.sut.proxiedRequest(withPath: url.absoluteString, method:.methodGET, type:.giphy, callback: callback)
        
        //then
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        let request = self.sut.proxiedRequestStatus.pendingRequests.first
        XCTAssert(request != nil)
        XCTAssertEqual(request!.path, path)
        XCTAssert(request!.callback != nil)
        request!.callback!(nil, HTTPURLResponse(), nil)
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
    }

    func testThatAddingRequestStartsOperationLoop() {
        
        //given
        let exp = self.expectation(description: "new operation loop started")
        let token = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "RequestAvailableNotification"), object: nil, queue: nil) { (note) -> Void in
            exp.fulfill()
        }
        
        let url = URL(string: "foo/bar", relativeTo: nil)!
        let callback: (Data?, URLResponse?, Error?) -> Void = { (_, _, _) -> Void in }
        
        //when
        self.sut.proxiedRequest(withPath: url.absoluteString, method:.methodGET, type:.giphy, callback: callback)
        
        //then
        XCTAssertTrue(self.waitForCustomExpectations(withTimeout: 0.5))
        
        NotificationCenter.default.removeObserver(token)
    }

    func testThatAddingRequestIsMadeOnSyncThread() {
        
        //given
        let url = URL(string: "foo/bar", relativeTo: nil)!
        let callback: (Data?, URLResponse?, Error?) -> Void = { (_, _, _) -> Void in }

        //here we block sync thread and check that right after giphyRequestWithURL call no request is created
        //after we signal semaphore sync thread should be unblocked and pending request should be created
        let sem = DispatchSemaphore(value: 0)
        self.syncMOC.performGroupedBlock {
            _ = sem.wait(timeout: DispatchTime.distantFuture)
        }

        //when
        self.sut.proxiedRequest(withPath: url.absoluteString, method:.methodGET, type:.giphy, callback: callback)
        
        //then
        var request = self.sut.proxiedRequestStatus.pendingRequests.first
        XCTAssertTrue(request == nil)

        //when
        sem.signal()
        
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        //then
        request = self.sut.proxiedRequestStatus.pendingRequests.first
        XCTAssert(request != nil)
        
    }
}
