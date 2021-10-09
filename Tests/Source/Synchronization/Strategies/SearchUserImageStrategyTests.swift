//

@testable import WireSyncEngine

let UserRequestURL = "/users?ids="

class FakeSearchDirectory : NSObject {}

extension SearchUserImageStrategyTests: ZMManagedObjectContextProvider {
    
    var managedObjectContext: NSManagedObjectContext! {
        return uiMOC
    }
    
    var syncManagedObjectContext: NSManagedObjectContext! {
        return syncMOC
    }
    
}

class SearchUserImageStrategyTests : MessagingTest {
    
    var sut: SearchUserImageStrategy!
    var mockApplicationStatus : MockApplicationStatus!
    
    override func setUp() {
        super.setUp()
        uiMOC.zm_searchUserCache = NSCache()
        mockApplicationStatus = MockApplicationStatus()
        mockApplicationStatus.mockSynchronizationState = .eventProcessing
        sut = SearchUserImageStrategy(applicationStatus: mockApplicationStatus, managedObjectContext: uiMOC)
    }
    
    override func tearDown() {
        sut = nil
        uiMOC.zm_searchUserCache = nil
        mockApplicationStatus = nil
        super.tearDown()
    }
    
    func createSearchUser() -> ZMSearchUser {
        return ZMSearchUser(contextProvider: self, name: "Foo", handle: "foo", accentColor: .brightOrange, remoteIdentifier: UUID())
    }
    
    func userIDs(from searchUsers: Set<ZMSearchUser>) -> Set<UUID> {
        return Set(searchUsers.compactMap { $0.remoteIdentifier })
    }
    
    func userData(previewAssetKey: String?, completeAssetKey: String? = nil, for userID: UUID) -> [String : Any] {
        return [
            "id" : userID.transportString(),
            "assets" : assetPayload(previewAssetKey: previewAssetKey, completeAssetKey: completeAssetKey)
        ]
    }

    func assetPayload(previewAssetKey: String?, completeAssetKey: String? = nil) -> [[String: Any]] {
        return [
            [
                "size": "preview",
                "type": "image",
                "key": previewAssetKey ?? UUID().transportString()
            ],
            [
                "size": "complete",
                "type": "image",
                "key": completeAssetKey ?? UUID().transportString()
            ]
        ]
    }

    func userIDs(in getRequest: ZMTransportRequest) -> Set<UUID> {
        if !getRequest.path.hasPrefix(UserRequestURL) {
            return Set()
        }
        let userIDs = String(getRequest.path[UserRequestURL.endIndex...])
        let tokens = userIDs.components(separatedBy: ",").compactMap { UUID(uuidString:$0) }
        return Set(tokens)
    }
    
    func setupSearchDirectory(userCount: Int) -> Set<ZMSearchUser> {
        var users = Set<ZMSearchUser>()
        for _ in 0..<userCount {
            let user = createSearchUser()
            users.insert(user)
        }
        return users
    }
}

extension SearchUserImageStrategyTests {
    
    func testThatItReturnsNoRequestIfThereIsNoRequestUserProfile() {
        // given
        _ = setupSearchDirectory(userCount: 1)

        // when
        let request = sut.nextRequest()

        // then
        XCTAssertNil(request);
    }
    
    func testThatNextRequestCreatesARequestForAllUserIDsWeHaveRequested(){
        // given
        let searchSet = setupSearchDirectory(userCount: 3)
        searchSet.forEach({ $0.requestPreviewProfileImage() })
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        
        // then
        XCTAssertNotNil(request);
        XCTAssertEqual(request.method, .methodGET);
        XCTAssertTrue(request.needsAuthentication);
        
        XCTAssertTrue(request.path.hasPrefix(UserRequestURL))
        let expectedUserIDs = userIDs(from: searchSet)
        XCTAssertEqual(userIDs(in:request), expectedUserIDs)
    }
    
    func testThatNextRequestDoesNotCreateARequestClientNotReady(){
        // given
        let searchSet = setupSearchDirectory(userCount: 3)
        searchSet.forEach({ $0.requestPreviewProfileImage() })
        mockApplicationStatus.mockSynchronizationState = .unauthenticated
        
        // when
        let request = sut.nextRequest()
        
        // then
        XCTAssertNil(request);
    }

    func testThatNextRequestCreatesARequestForAllUserIDsForAllUserIDsWeHaveRequestedThatWeAreNotAlreadyRequesting() {
        // given
        let searchSet1 = setupSearchDirectory(userCount: 2)
        searchSet1.forEach({ $0.requestPreviewProfileImage() })
        guard sut.nextRequest() != nil else { return XCTFail() } // start first request
        
        // when
        let searchSet2 = setupSearchDirectory(userCount: 1)
        searchSet2.forEach({ $0.requestPreviewProfileImage() })
        guard let request2 = sut.nextRequest() else { return XCTFail() }
        
        // then
        XCTAssertNotNil(request2)
        XCTAssertEqual(request2.method, .methodGET)
        XCTAssertTrue(request2.needsAuthentication)
        
        let expectedUserIDs = userIDs(from: searchSet2)
        XCTAssertEqual(userIDs(in:request2), expectedUserIDs)
    }
    
    func testThatCompletingARequestUpdatesAssetKeysOnSearchUsers_AssetKeys() {
        // Given
        let searchUsers = Array(setupSearchDirectory(userCount: 2))
        let searchUser1 = searchUsers.first!
        let searchUser2 = searchUsers.last!
        searchUsers.forEach({ $0.requestPreviewProfileImage() })

        let previewAssetKey1 = "previewAssetKey1", completeAssetKey1 = "completeAssetKey1"
        let previewAssetKey2 = "previewAssetKey2", completeAssetKey2 = "completeAssetKey2"

        let payload = [
            userData(previewAssetKey: previewAssetKey1, completeAssetKey: completeAssetKey1, for: searchUser1.remoteIdentifier!),
            userData(previewAssetKey: previewAssetKey2, completeAssetKey: completeAssetKey2, for: searchUser2.remoteIdentifier!)
        ]

        let response = ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil)

        // When
        guard let request = sut.nextRequest() else { return XCTFail() }
        request.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // Then
        XCTAssertEqual(searchUser1.assetKeys?.preview, previewAssetKey1)
        XCTAssertEqual(searchUser1.assetKeys?.complete, completeAssetKey1)
        
        XCTAssertEqual(searchUser2.assetKeys?.preview, previewAssetKey2)
        XCTAssertEqual(searchUser2.assetKeys?.complete, completeAssetKey2)
    }

    func testThatAFailingUserProfileRequestWithAPermanentErrorClearsThemFromTheDownloadQueue() {
        // given
        let searchUsers = setupSearchDirectory(userCount: 2)
        searchUsers.forEach({ $0.requestPreviewProfileImage() })
        let response = ZMTransportResponse(payload: nil, httpStatus: 400, transportSessionError: nil)
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        request.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertNil(sut.nextRequest())
    }
    
    func testThatFailingAUserProfileRequestWithATemporaryErrorAllowsThemToBeDownloadedAgain() {
        // given
        let searchUsers = setupSearchDirectory(userCount: 2)
        searchUsers.forEach({ $0.requestPreviewProfileImage() })
        let response = ZMTransportResponse(payload: nil, httpStatus: 500, transportSessionError: nil)
        
        // when
        guard let request1 = sut.nextRequest() else { return XCTFail() }
        request1.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let request2 = sut.nextRequest() else { return XCTFail() }
        let expectedUserIDs = userIDs(from: searchUsers)
        XCTAssertEqual(userIDs(in:request2), expectedUserIDs)
    }
    
    func testThatCompletingAUserProfileRequestDoesNotAllowForThemToBeDownloadedAgain() {
        // given
        let searchUsers = Array(setupSearchDirectory(userCount: 2))
        searchUsers.forEach({ $0.requestPreviewProfileImage() })
        

        let payload = [
            userData(previewAssetKey: UUID().transportString(), for: searchUsers.first!.remoteIdentifier!),
            userData(previewAssetKey: UUID().transportString(), for: searchUsers.last!.remoteIdentifier!)
        ]
        let response = ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil)
        
        // when
        guard let request1 = sut.nextRequest() else { return XCTFail() }
        request1.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let request2 = sut.nextRequest() else { return XCTFail() }
        XCTAssertEqual(userIDs(in:request2).count, 0)
    }
    
}


// MARK: - ImageAssets

extension SearchUserImageStrategyTests {
    
    func testThatNextRequestCreatesARequestForAnAssetID() {
        // given
        let searchUser = setupSearchDirectory(userCount: 1).first!
        let assetID = UUID().transportString()
        searchUser.update(from: userData(previewAssetKey: assetID, for: searchUser.remoteIdentifier!))
        searchUser.requestPreviewProfileImage()
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        
        // then
        XCTAssertNotNil(request);
        XCTAssertEqual(request.method, .methodGET);
        XCTAssertTrue(request.needsAuthentication);
        
        let expectedPath = "/assets/v3/\(assetID)"
        XCTAssertEqual(request.path, expectedPath);
    }
    
    func testThatNextRequestDoesNotCreatesARequestForAnAssetIDIfTheFirstRequestIsStillRunning() {
        // given
        let searchUser = setupSearchDirectory(userCount: 1).first!
        let assetID = UUID().transportString()
        searchUser.update(from: userData(previewAssetKey: assetID, for: searchUser.remoteIdentifier!))
        searchUser.requestPreviewProfileImage()
        
        // when
        let request1 = sut.nextRequest()
        let request2 = sut.nextRequest()
        
        // then
        XCTAssertNotNil(request1);
        XCTAssertNil(request2);
    }
    
    func testThatNextRequestCreatesARequestForAnAssetIDThatWeAreNotAlreadyRequesting() {
        // given
        let searchUser1 = setupSearchDirectory(userCount: 1).first!
        let searchUser2 = setupSearchDirectory(userCount: 1).first!
        
        let assetID1 = UUID().transportString()
        let assetID2 = UUID().transportString()
        
        searchUser1.update(from: userData(previewAssetKey: assetID1, for: searchUser1.remoteIdentifier!))
        searchUser2.update(from: userData(previewAssetKey: assetID2, for: searchUser2.remoteIdentifier!))
        searchUser1.requestPreviewProfileImage()
        searchUser2.requestPreviewProfileImage()
        
        // when
        guard let request1 = sut.nextRequest() else { return XCTFail() }
        guard let request2 = sut.nextRequest() else { return XCTFail() }

        // then
        XCTAssertNotNil(request1);
        XCTAssertEqual(request1.method, .methodGET);
        XCTAssertTrue(request1.needsAuthentication);
        
        XCTAssertNotNil(request2);
        XCTAssertEqual(request2.method, .methodGET);
        XCTAssertTrue(request2.needsAuthentication);
        
        let expectedPath1 = "/assets/v3/\(assetID1)" //requestPath(for:assetID1, of:searchUser1.remoteIdentifier!)
        let expectedPath2 = "/assets/v3/\(assetID2)" //requestPath(for:assetID2, of:searchUser2.remoteIdentifier!)
        XCTAssertTrue(request1.path == expectedPath1 || request1.path == expectedPath2)
        XCTAssertTrue(request2.path == expectedPath1 || request2.path == expectedPath2)
        XCTAssertNotEqual(request2.path, request1.path)
    }
    
    
    func testThatCompletingARequestUpdatesTheImageDataOnSearchUser() {
        // given
        let imageData = verySmallJPEGData()
        let searchUser1 = setupSearchDirectory(userCount: 1).first!
        let assetID1 = UUID().transportString()
        searchUser1.update(from: userData(previewAssetKey: assetID1, for: searchUser1.remoteIdentifier!))
        searchUser1.requestPreviewProfileImage()
        
        let response = ZMTransportResponse(imageData: imageData, httpStatus: 200, transportSessionError: nil, headers: nil)
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        XCTAssertEqual(request.path, "/assets/v3/\(assetID1)");

        request.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(searchUser1.previewImageData, imageData)
    }
    
    func testThatCompletingARequestRemovesTheAssetFromTheDownloadQueue() {
        // given
        let imageData = verySmallJPEGData()
        let searchUser1 = setupSearchDirectory(userCount: 1).first!
        let assetID1 = UUID().transportString()
        searchUser1.update(from: userData(previewAssetKey: assetID1, for: searchUser1.remoteIdentifier!))
        searchUser1.requestPreviewProfileImage()
        
        let response = ZMTransportResponse(imageData: imageData, httpStatus: 200, transportSessionError: nil, headers: nil)
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        XCTAssertEqual(request.path, "/assets/v3/\(assetID1)");
        
        request.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertNil(sut.nextRequest())
    }
    
    func testThatFailingAnAssetRequestWithAPermanentErrorDeletesAssetKeysFromSearchUser() {
        // given
        let searchUser1 = setupSearchDirectory(userCount: 1).first!
        let assetID1 = UUID().transportString()
        searchUser1.update(from: userData(previewAssetKey: assetID1, for: searchUser1.remoteIdentifier!))
        searchUser1.requestPreviewProfileImage()
        let response = ZMTransportResponse(payload: nil, httpStatus: 400, transportSessionError: nil)
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        XCTAssertEqual(request.path, "/assets/v3/\(assetID1)");
        
        request.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertNil(searchUser1.assetKeys)
    }
    
    func testThatFailingAnAssertRequestWithATemporaryErrorAllowsForThoseAssetIDsToBeDownloadedAgain() {
        // given
        let searchUser1 = setupSearchDirectory(userCount: 1).first!
        let assetID1 = UUID().transportString()
        searchUser1.update(from: userData(previewAssetKey: assetID1, for: searchUser1.remoteIdentifier!))
        searchUser1.requestPreviewProfileImage()
        
        let response = ZMTransportResponse(payload: nil, httpStatus: 500, transportSessionError: nil)
        
        // when
        guard let request1 = sut.nextRequest() else { return XCTFail() }
        XCTAssertEqual(request1.path, "/assets/v3/\(assetID1)");
        
        request1.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let request2 = sut.nextRequest() else { return XCTFail() }
        XCTAssertEqual(request2.path, "/assets/v3/\(assetID1)");
    }
    
    func testThatItNotifiesTheSearchUserWhenAnImageIsDownloaded_preview() {
        // given
        let imageData = verySmallJPEGData()
        let searchUser1 = setupSearchDirectory(userCount: 1).first!
        let assetID1 = UUID().transportString()
        searchUser1.update(from: userData(previewAssetKey: assetID1, for: searchUser1.remoteIdentifier!))
        searchUser1.requestPreviewProfileImage()
        
        let response = ZMTransportResponse(imageData: imageData, httpStatus: 200, transportSessionError: nil, headers: nil)
        uiMOC.searchUserObserverCenter.addSearchUser(searchUser1) // This is called when the searchDirectory returns the searchUsers
        let userObserver = UserChangeObserver(user: searchUser1, managedObjectContext:self.uiMOC)!
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        request.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let note = userObserver.notifications.firstObject as? UserChangeInfo else { return XCTFail() }
        XCTAssertTrue(note.imageSmallProfileDataChanged)
        XCTAssertEqual(note.user as? ZMSearchUser, searchUser1)
    }
    
    func testThatItNotifiesTheSearchUserWhenAnImageIsDownloaded_complete() {
        // given
        let imageData = verySmallJPEGData()
        let searchUser1 = setupSearchDirectory(userCount: 1).first!
        let previewAssetKey = "previewKey123"
        let completeAssetKey = "previewKey123"
        searchUser1.update(from: userData(previewAssetKey: previewAssetKey, completeAssetKey: completeAssetKey, for: searchUser1.remoteIdentifier!))
        searchUser1.requestCompleteProfileImage()
        
        let response = ZMTransportResponse(imageData: imageData, httpStatus: 200, transportSessionError: nil, headers: nil)
        uiMOC.searchUserObserverCenter.addSearchUser(searchUser1) // This is called when the searchDirectory returns the searchUsers
        let userObserver = UserChangeObserver(user: searchUser1, managedObjectContext:self.uiMOC)!
        
        // when
        guard let request = sut.nextRequest() else { return XCTFail() }
        request.complete(with: response)
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        guard let note = userObserver.notifications.firstObject as? UserChangeInfo else { return XCTFail() }
        XCTAssertTrue(note.imageMediumDataChanged)
        XCTAssertEqual(note.user as? ZMSearchUser, searchUser1)
    }

}
