//

import XCTest

@testable import WireSyncEngine

class TeamInvitationRequestStrategyTests: MessagingTest {
    
    var applicationStatus : MockApplicationStatus!
    var teamInvitationStatus : TeamInvitationStatus!
    var team : Team!
    var sut : TeamInvitationRequestStrategy!
    
    override func setUp() {
        super.setUp()
        
        applicationStatus = MockApplicationStatus()
        teamInvitationStatus = TeamInvitationStatus()
        sut = TeamInvitationRequestStrategy(withManagedObjectContext: syncMOC, applicationStatus: applicationStatus, teamInvitationStatus: teamInvitationStatus)
        applicationStatus.mockOperationState = .foreground
        applicationStatus.mockSynchronizationState = .eventProcessing
    }
    
    override func tearDown() {
        sut = nil
        applicationStatus = nil
        teamInvitationStatus = nil
        team = nil
        
        super.tearDown()
    }
    
    func addSelfUserToTeam() {
        let selfUser = ZMUser.selfUser(in: syncMOC)
        selfUser.name = "Self User"
        let team = Team.insertNewObject(in: syncMOC)
        team.remoteIdentifier = UUID.create()
        
        let member = Member.insertNewObject(in: syncMOC)
        member.remoteIdentifier = UUID.create()
        member.user = selfUser
        team.members.insert(member)
        
        self.team = team
    }
    
    func testThatRequestIsGeneratedWhenInvitationIsPending() {
        // given
        addSelfUserToTeam()
        teamInvitationStatus.invite("example1@test.com", completionHandler: { _ in })
        
        // when
        let request = sut.nextRequest()
        
        // then
        XCTAssertEqual(request?.path, "/teams/\(team.remoteIdentifier!.transportString())/invitations")
        XCTAssertEqual(request?.payload?.asDictionary()?["email"] as? String, "example1@test.com")
        XCTAssertEqual(request?.payload?.asDictionary()?["inviter_name"] as? String, "Self User")
    }
    
    func testThatRequestIsGeneratedOnlyOncePerInvitation() {
        // given
        addSelfUserToTeam()
        teamInvitationStatus.invite("example1@test.com", completionHandler: { _ in })
        
        // when
        let request1 = sut.nextRequest()
        let request2 = sut.nextRequest()
        
        // then
        XCTAssertEqual(request1?.path, "/teams/\(team.remoteIdentifier!.transportString())/invitations")
        XCTAssertNil(request2)
    }
    
    func testThatRequestIsRetriedOnTemporaryErrors() {
        // given
        addSelfUserToTeam()
        teamInvitationStatus.invite("example1@test.com", completionHandler: { _ in })
        
        // when
        let request = sut.nextRequest()
        request?.complete(with: ZMTransportResponse(payload: nil, httpStatus: 408, transportSessionError: nil))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let retryRequest = sut.nextRequest()
        XCTAssertEqual(retryRequest?.path, "/teams/\(team.remoteIdentifier!.transportString())/invitations")
        XCTAssertEqual(retryRequest?.payload?.asDictionary()?["email"] as? String, "example1@test.com")
        XCTAssertEqual(retryRequest?.payload?.asDictionary()?["inviter_name"] as? String, "Self User")
    }
    
    func testInvitationResultParsing() {
        
        let responseCases = [(201, ""),
                             (403, "too-many-team-invitations"),
                             (403, "blacklisted-email"),
                             (403, "invalid-email"),
                             (403, "no-identity"),
                             (403, "no-email"),
                             (409, "email-exists"),
                             (404, "unknown-error")]
        
        let responses : [ZMTransportResponse] = responseCases.map { value in
            let (httpStatus, label) = value
            let payload : [String : Any] = [
                "label" : label,
                "code" : httpStatus
            ]
            
            return ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: httpStatus, transportSessionError: nil)
        }
        
        let inviteResults = responses.map({ InviteResult.init(response: $0, email: "")})
        let expectedResults : [InviteResult] = [.success(email: ""),
                                                .failure(email: "", error: .tooManyTeamInvitations),
                                                .failure(email: "", error: .blacklistedEmail),
                                                .failure(email: "", error: .invalidEmail),
                                                .failure(email: "", error: .noIdentity),
                                                .failure(email: "", error: .noEmail),
                                                .failure(email: "", error: .alreadyRegistered),
                                                .failure(email: "", error: .unknown)]
        
        zip(inviteResults, expectedResults).forEach { tuple in
            let (result, expectedResult) = tuple
            XCTAssertTrue(result == expectedResult)
        }
    }
    
}

extension TeamInvitationRequestStrategyTests : ZMRequestCancellation, ZMSyncStateDelegate {
    
    func cancelTask(with taskIdentifier: ZMTaskIdentifier) { }
    
    func didStartSlowSync() { }
    
    func didFinishSlowSync() { }
    
    func didStartQuickSync() { }
    
    func didFinishQuickSync() { }
    
    func didRegister(_ userClient: UserClient!) { }
    
}
