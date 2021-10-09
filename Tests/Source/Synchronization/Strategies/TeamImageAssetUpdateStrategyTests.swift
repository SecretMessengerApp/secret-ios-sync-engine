//

import Foundation
import XCTest
@testable import WireSyncEngine

final class TeamImageAssetUpdateStrategyTests : MessagingTest {

    var sut: TeamImageAssetUpdateStrategy!
    var mockApplicationStatus : MockApplicationStatus!
    let pictureAssetId = "blah"

    override func setUp() {
        super.setUp()
        
        self.mockApplicationStatus = MockApplicationStatus()
        self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
        
        sut = TeamImageAssetUpdateStrategy(withManagedObjectContext: uiMOC, applicationStatus: mockApplicationStatus)
    }

    override func tearDown() {
        mockApplicationStatus = nil
        sut = nil
        
        super.tearDown()
    }

    private func createTeamWithImage() -> Team {
        let team = Team(context: uiMOC)
        team.pictureAssetId = pictureAssetId
        team.remoteIdentifier = UUID()
        uiMOC.saveOrRollback()

        return team
    }
    
    func testThatItDoesNotCreateRequestForTeamImageAsset_BeforeRequestingImage() {
        // GIVEN
        _ = createTeamWithImage()
        
        // THEN
        let request = sut.nextRequest()
        XCTAssertNil(request)
    }

    func testThatItCreatesRequestForTeamImageAsset_AfterRequestingImage() {
        // GIVEN
        let team = createTeamWithImage()

        // WHEN
        team.requestImage()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        let request = sut.nextRequest()
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.path, "/assets/v3/\(pictureAssetId)")
        XCTAssertEqual(request?.method, .methodGET)
    }

    func testThatItStoresTeamImageAsset_OnSuccessfulResponse() {
        // GIVEN
        let team = createTeamWithImage()
        let imageData = "image".data(using: .utf8)!
        
        team.requestImage()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        guard let request = sut.nextRequest() else { return XCTFail("nil request generated") }
        
        // WHEN
        request.complete(with: ZMTransportResponse(imageData: imageData, httpStatus: 200, transportSessionError: nil, headers: nil))
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertEqual(team.imageData, imageData)
    }

    func testThatItDeletesTeamAssetIdentifier_OnPermanentError() {
        // GIVEN
        let team = createTeamWithImage()
        team.requestImage()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        guard let request = sut.nextRequest() else { return XCTFail("nil request generated") }

        // WHEN
        request.complete(with: ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil))
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // THEN
        XCTAssertNil(team.pictureAssetId)
    }
}
