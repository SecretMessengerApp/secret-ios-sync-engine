//

import Foundation
import XCTest

@testable import WireSyncEngine

final class DummyServiceUser: NSObject, ServiceUser {

    var hasLegalHoldRequest: Bool = false
    
    var needsRichProfileUpdate: Bool = false
    
    var availability: Availability = .none
    
    var teamName: String? = nil
    
    var isBlocked: Bool = false
    
    var isExpired: Bool = false
    
    var isPendingApprovalBySelfUser: Bool = false
    
    var isPendingApprovalByOtherUser: Bool = false
    
    var isWirelessUser: Bool = false
    
    var isUnderLegalHold: Bool = false

    var allClients: [UserClientType]  = []
    
    var expiresAfter: TimeInterval = 0
    
    var readReceiptsEnabled: Bool = true
    
    var richProfile: [UserRichProfileField] = []
    
    var canCreateConversation: Bool = false
    
    var canCreateService: Bool = false
    
    var canManageTeam: Bool = false
    
    func canAccessCompanyInformation(of user: UserType) -> Bool {
        return false
    }
    
    func canAddUser(to conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canRemoveUser(from conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canAddService(to conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canDeleteConversation(_ conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canRemoveService(from conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canModifyReadReceiptSettings(in conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canModifyEphemeralSettings(in conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canModifyNotificationSettings(in conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canModifyAccessControlSettings(in conversation: ZMConversation) -> Bool {
        return false
    }
    
    func canModifyTitle(in conversation: ZMConversation) -> Bool {
        return false
    }
    
    var previewImageData: Data? = nil
    
    var completeImageData: Data? = nil
    
    var name: String? = "Service user"
    
    var displayName: String = "Service"
    
    var initials: String? = "S"
    
    var handle: String? = "service"
    
    var emailAddress: String? = "dummy@email.com"
    
    var isSelfUser: Bool = false
    
    var smallProfileImageCacheKey: String? = ""
    
    var mediumProfileImageCacheKey: String? = ""
    
    var isConnected: Bool = false

    var oneToOneConversation: ZMConversation? = nil
    
    var accentColorValue: ZMAccentColor = ZMAccentColor.brightOrange
    
    var imageMediumData: Data! = Data()
    
    var imageSmallProfileData: Data! = Data()
    
    var imageSmallProfileIdentifier: String! = ""
    
    var imageMediumIdentifier: String! = ""
    
    var isTeamMember: Bool = false
    
    var teamRole: TeamRole = .member
    
    var canBeConnected: Bool = false
    
    var isServiceUser: Bool = true

    var usesCompanyLogin: Bool = false
    
    var isAccountDeleted: Bool = false
    
    var managedByWire: Bool = true
    
    var extendedMetadata: [[String : String]]? = nil
    
    var activeConversations: Set<ZMConversation> = Set()
    
    func requestPreviewProfileImage() {
        
    }
    
    func requestCompleteProfileImage() {
        
    }
    
    func imageData(for size: ProfileImageSize, queue: DispatchQueue, completion: @escaping (Data?) -> Void) {
        
    }
    
    func refreshData() {
        
    }
    
    func connect(message: String) {
        
    }
    
    func isGuest(in conversation: ZMConversation) -> Bool {
        return false
    }
    
    var connectionRequestMessage: String? = ""
    
    var totalCommonConnections: UInt = 0
    
    var serviceIdentifier: String?
    var providerIdentifier: String?
    
    init(serviceIdentifier: String, providerIdentifier: String) {
        self.serviceIdentifier = serviceIdentifier
        self.providerIdentifier = providerIdentifier
        super.init()
    }
    
}

final class ServiceUserTests : IntegrationTest {
    public override func setUp() {
        super.setUp()
        self.createSelfUserAndConversation()
        self.createExtraUsersAndConversations()
        
        XCTAssertTrue(self.login())
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }
    
    func createService() -> ServiceUser {
        var mockServiceId: String!
        var mockProviderId: String!
        mockTransportSession.performRemoteChanges { (remoteChanges) in
            let mockService = remoteChanges.insertService(withName: "Service A",
                                                          identifier: UUID().transportString(),
                                                          provider: UUID().transportString())
            
            mockServiceId = mockService.identifier
            mockProviderId = mockService.provider
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        return DummyServiceUser(serviceIdentifier: mockServiceId, providerIdentifier: mockProviderId)
    }
    
    func testThatItAddsServiceToExistingConversation() throws {
        // given
        let jobIsDone = expectation(description: "service is added")
        let service = self.createService()
        let conversation = self.conversation(for: self.groupConversation)!
        
        // when
        conversation.add(serviceUser: service, in: self.userSession!, completion: { error in
            // expect
            XCTAssertNil(error)
            jobIsDone.fulfill()
        })
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatItCreatesConversationAndAddsUser() {
        // given
        let jobIsDone = expectation(description: "service is added")
        let service = self.createService()
       
        // when
        self.userSession!.startConversation(with: service) { conversation in
            XCTAssertNotNil(conversation)
            jobIsDone.fulfill()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
    }
    
    func testThatItDetectsTheSuccessResponse() {
        // GIVEN
        let response = ZMTransportResponse(payload: nil, httpStatus: 201, transportSessionError: nil)
        // WHEN
        let error = AddBotError(response: response)
        // THEN
        XCTAssertEqual(error, nil)
    }
    
    func testThatItDetectsTheConversationFullResponse() {
        // GIVEN
        let response = ZMTransportResponse(payload: nil, httpStatus: 403, transportSessionError: nil)
        // WHEN
        let error = AddBotError(response: response)
        // THEN
        XCTAssertEqual(error, .tooManyParticipants)
    }
    
    func testThatItDetectsBotRejectedResponse() {
        // GIVEN
        let response = ZMTransportResponse(payload: nil, httpStatus: 419, transportSessionError: nil)
        // WHEN
        let error = AddBotError(response: response)
        // THEN
        XCTAssertEqual(error, .botRejected)
    }
    
    func testThatItDetectsBotNotResponding() {
        // GIVEN
        let response = ZMTransportResponse(payload: nil, httpStatus: 502, transportSessionError: nil)
        // WHEN
        let error = AddBotError(response: response)
        // THEN
        XCTAssertEqual(error, .botNotResponding)
    }
    
    func testThatItDetectsGeneralError() {
        // GIVEN
        let response = ZMTransportResponse(payload: nil, httpStatus: 500, transportSessionError: nil)
        // WHEN
        let error = AddBotError(response: response)
        // THEN
        XCTAssertEqual(error, .general)
    }
}
