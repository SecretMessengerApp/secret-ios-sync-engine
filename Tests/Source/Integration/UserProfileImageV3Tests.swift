//

import Foundation
@testable import WireSyncEngine
import WireMockTransport

class UserProfileImageV3Tests: IntegrationTest {
    
    override func setUp() {
        super.setUp()
        
        createSelfUserAndConversation()
    }
    
    func checkProfileImagesMatch(local: ZMUser, remote: MockUser, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(remote.completeProfileAssetIdentifier, "Complete assetId should bet set on remote user", file: file, line: line)
        XCTAssertNotNil(remote.previewProfileAssetIdentifier, "Preview assetId should bet set on remote user", file: file, line: line)
        XCTAssertNotNil(local.completeProfileAssetIdentifier, "Complete assetId should bet set on local user", file: file, line: line)
        XCTAssertNotNil(local.previewProfileAssetIdentifier, "Preview assetId should bet set on local user", file: file, line: line)

        guard let previewId = remote.previewProfileAssetIdentifier, let completeId = remote.completeProfileAssetIdentifier else { return }
        let previewAsset = MockAsset(in: mockTransportSession.managedObjectContext, forID: previewId)
        let completeAsset = MockAsset(in: mockTransportSession.managedObjectContext, forID: completeId)
        checkProfileImagesMatch(local: local, previewAsset: previewAsset, completeAsset: completeAsset, file: file, line: line)
    }
    
    func checkProfileImagesMatch(local: ZMUser, previewAsset: MockAsset?, completeAsset: MockAsset?, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(completeAsset, "Complete asset should exist on server", file: file, line: line)
        XCTAssertNotNil(previewAsset, "Complete asset should exist on server", file: file, line: line)
        
        XCTAssertEqual(local.previewProfileAssetIdentifier, previewAsset?.identifier, "Preview assetId should match remote assetId", file: file, line: line)
        XCTAssertEqual(local.completeProfileAssetIdentifier, completeAsset?.identifier, "Complete assetId should match remote assetId", file: file, line: line)
        XCTAssertEqual(local.imageMediumData, completeAsset?.data, "Complete asset should match remote data", file: file, line: line)
        XCTAssertEqual(local.imageSmallProfileData, previewAsset?.data, "Preview asset should match remote data", file: file, line: line)
    }
        
    func testThatSelfUserImagesAreUploadedWhenThereAreNone() {
        // GIVEN
        mockTransportSession.performRemoteChanges { session in
            self.selfUser.pictures = []
            self.selfUser.previewProfileAssetIdentifier = nil
            self.selfUser.completeProfileAssetIdentifier = nil
        }
        XCTAssertTrue(login())

        // WHEN
        userSession?.performChanges {
            self.userSession?.profileUpdate.updateImage(imageData: self.mediumJPEGData())
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        if let userProfileImageUpdateStatus = self.userSession?.profileUpdate as? UserProfileImageUpdateStatus {
            // wait until image pre-processing is completed
            userProfileImageUpdateStatus.queue.waitUntilAllOperationsAreFinished()
        }
        
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        checkProfileImagesMatch(local: ZMUser.selfUser(inUserSession: userSession!), remote: selfUser)
    }
    
    func testThatSelfUserImagesAreChanged() {
        // GIVEN
        XCTAssertTrue(login())
        
        // WHEN
        userSession?.performChanges {
            self.userSession?.profileUpdate.updateImage(imageData: self.mediumJPEGData())
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        checkProfileImagesMatch(local: ZMUser.selfUser(inUserSession: userSession!), remote: selfUser)
    }
    
    func testThatOldSelfUserImagesAreDeletedAfterChange() {
        // GIVEN
        XCTAssertTrue(login())
        let currentUser = ZMUser.selfUser(inUserSession: userSession!)
        let completeId = currentUser.completeProfileAssetIdentifier
        let previewId = currentUser.previewProfileAssetIdentifier
        XCTAssertNotNil(completeId)
        XCTAssertNotNil(previewId)
        
        // WHEN
        userSession?.performChanges {
            self.userSession?.profileUpdate.updateImage(imageData: self.mediumJPEGData())
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        if let userProfileImageUpdateStatus = self.userSession?.profileUpdate as? UserProfileImageUpdateStatus {
            // wait until image pre-processing is completed
            userProfileImageUpdateStatus.queue.waitUntilAllOperationsAreFinished()
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        let previewAsset = MockAsset(in: mockTransportSession.managedObjectContext, forID: previewId!)
        XCTAssertNil(previewAsset)
        let completeAsset = MockAsset(in: mockTransportSession.managedObjectContext, forID: completeId!)
        XCTAssertNil(completeAsset)
    }

    func testThatSelfUserImagesAreDownloadedIfAddedRemotely() {
        // GIVEN
        mockTransportSession.performRemoteChanges { session in
            self.selfUser.pictures = []
            session.addV3ProfilePicture(to: self.selfUser)
        }
        XCTAssertTrue(login())
        
        // THEN
        checkProfileImagesMatch(local: ZMUser.selfUser(inUserSession: userSession!), remote: selfUser)
    }

    func testThatSelfUserImagesAreDownloadedIfChangedRemotely() {
        // GIVEN
        XCTAssertTrue(login())

        // WHEN
        var assets: [String : MockAsset]?
        mockTransportSession.performRemoteChanges { session in
            assets = session.addV3ProfilePicture(to: self.selfUser)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // THEN
        let localUser = ZMUser.selfUser(inUserSession: userSession!)
        let completeAsset = assets?["complete"]
        let previewAsset = assets?["preview"]
        checkProfileImagesMatch(local: localUser, previewAsset: previewAsset, completeAsset: completeAsset)
    }

}

