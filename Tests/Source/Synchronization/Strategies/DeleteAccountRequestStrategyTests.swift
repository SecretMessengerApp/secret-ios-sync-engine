//


import Foundation
import WireSyncEngine
import WireTransport

class DeleteAccountRequestStrategyTests: MessagingTest, PostLoginAuthenticationObserver {
    
    fileprivate var sut : DeleteAccountRequestStrategy!
    fileprivate var mockApplicationStatus : MockApplicationStatus!
    fileprivate let cookieStorage = ZMPersistentCookieStorage()
    private var accountDeleted: Bool = false
    var observers: [Any] = []
    
    override func setUp() {
        super.setUp()
        self.mockApplicationStatus = MockApplicationStatus()
        self.sut = DeleteAccountRequestStrategy(withManagedObjectContext: self.uiMOC, applicationStatus:mockApplicationStatus, cookieStorage: cookieStorage)
    }
    
    override func tearDown() {
        self.sut = nil
        self.observers = []
        super.tearDown()
    }
    
    func testThatItGeneratesNoRequestsIfTheStatusIsEmpty() {
        XCTAssertNil(self.sut.nextRequest())
    }
    
    func testThatItGeneratesARequest() {
        
        // given
        self.uiMOC.setPersistentStoreMetadata(NSNumber(value: true), key: DeleteAccountRequestStrategy.userDeletionInitiatedKey)
        
        // when
        let request : ZMTransportRequest? = self.sut.nextRequest()
        
        // then
        if let request = request {
            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodDELETE)
            XCTAssertEqual(request.path, "/self")
            XCTAssertTrue(request.needsAuthentication)
        } else {
            XCTFail("Empty request")
        }
    }
    
    func testThatItGeneratesARequestOnlyOnce() {
        
        // given
        self.uiMOC.setPersistentStoreMetadata(NSNumber(value: true), key: DeleteAccountRequestStrategy.userDeletionInitiatedKey)
        
        // when
        let request1 : ZMTransportRequest? = self.sut.nextRequest()
        let request2 : ZMTransportRequest? = self.sut.nextRequest()
        
        // then
        XCTAssertNotNil(request1)
        XCTAssertNil(request2)
        
    }
    
    func testThatItSignsUserOutWhenSuccessful() {
        // given
        ZMUser.selfUser(in: self.uiMOC).remoteIdentifier = UUID()
        self.uiMOC.setPersistentStoreMetadata(NSNumber(value: true), key: DeleteAccountRequestStrategy.userDeletionInitiatedKey)
        
        observers.append(PostLoginAuthenticationNotification.addObserver(self,
                                                        context: self.uiMOC))

        // when
        let request1 : ZMTransportRequest! = self.sut.nextRequest()
        request1.complete(with: ZMTransportResponse(payload: NSDictionary(), httpStatus: 201, transportSessionError: nil))
        
        // then
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertTrue(accountDeleted)
    }
    
    func accountDeleted(accountId : UUID) {
        self.accountDeleted = true
    }
}
