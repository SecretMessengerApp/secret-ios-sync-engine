//


import Foundation
import WireDataModel
@testable import WireSyncEngine

class TestTeamObserver : NSObject, TeamObserver {

    var token : NSObjectProtocol!
    var observedTeam : Team?
    var notifications: [TeamChangeInfo] = []
    
    init(team: Team? = nil, userSession: ZMUserSession) {
        super.init()
        token = TeamChangeInfo.add(observer: self, for: team, managedObjectContext: userSession.managedObjectContext)
    }
    
    func teamDidChange(_ changeInfo: TeamChangeInfo) {
        if let observedTeam = observedTeam, (changeInfo.team as? Team) != observedTeam {
            return
        }
        notifications.append(changeInfo)
    }
}

class TeamTests : IntegrationTest {
    
    override func setUp() {
        super.setUp()
        
        createSelfUserAndConversation()
        createExtraUsersAndConversations()
    }

    func remotelyInsertTeam(members: [MockUser], isBound: Bool = true) -> MockTeam {
        var mockTeam : MockTeam!
        mockTransportSession.performRemoteChanges { (session) in
            mockTeam = session.insertTeam(withName: "Super-Team", isBound: isBound, users: Set(members))
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        return mockTeam
    }
}


// MARK : Notifications

extension TeamTests {
    
    func testThatItNotifiesAboutChangedTeamName(){
        // given
        let mockTeam = remotelyInsertTeam(members: [self.selfUser, self.user1])

        XCTAssert(login())
        guard let localSelfUser = user(for: selfUser) else { return XCTFail() }
        XCTAssertTrue(localSelfUser.hasTeam)
        
        let teamObserver = TestTeamObserver(team: nil, userSession: userSession!)
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            mockTeam.name = "Super-Duper-Team"
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(teamObserver.notifications.count, 1)
        guard let note = teamObserver.notifications.last else {
            return XCTFail("no notification received")
        }
        XCTAssertTrue(note.nameChanged)
    }
}


// MARK : Member removal
extension TeamTests {
    
    func testThatOtherUserCanBeRemovedRemotely() {
        // given
        let mockTeam = remotelyInsertTeam(members: [self.selfUser, self.user1])

        XCTAssert(login())

        let user = self.user(for: user1)!
        let localSelfUser = self.user(for: selfUser)!
        XCTAssert(user.hasTeam)
        XCTAssert(localSelfUser.hasTeam)

        // when
        mockTransportSession.performRemoteChanges { (session) in
            session.removeMember(with: self.user1, from: mockTeam)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertFalse(user.hasTeam)
    }
    
    func testThatAccountIsDeletedWhenSelfUserIsRemovedFromTeam() {
        // given
        let mockTeam = remotelyInsertTeam(members: [self.selfUser, self.user1])

        XCTAssert(login())

        XCTAssert(ZMUser.selfUser(in: userSession!.managedObjectContext).hasTeam)
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            session.removeMember(with: self.selfUser, from: mockTeam)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertNil(userSession) // user should be logged from the account
        XCTAssertTrue(sessionManager!.accountManager.accounts.isEmpty) // account should be deleted
    }
    
    func testThatItNotifiesAboutOtherUserRemovedRemotely(){
        // given
        let mockTeam = remotelyInsertTeam(members: [self.selfUser, self.user1])

        XCTAssert(login())
        let teamObserver = TestTeamObserver(team: nil, userSession: userSession!)
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            session.removeMember(with: self.user1, from: mockTeam)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(teamObserver.notifications.count, 1)
        guard let change = teamObserver.notifications.last else {
            return XCTFail("no notification received")
        }
        XCTAssertTrue(change.membersChanged)
    }
    
}


// MARK : Member adding

extension TeamTests {
    
    func testThatOtherUserCanBeAddedRemotely(){
        // given
        let mockTeam = remotelyInsertTeam(members: [self.selfUser])
        XCTAssert(login())
        
        let user = self.user(for: user1)!
        XCTAssertFalse(user.hasTeam)
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            session.insertMember(with: self.user1, in: mockTeam)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssert(user.hasTeam)
    }
    
    func testThatItNotifiesAboutOtherUserAddedRemotely(){
        // given
        let mockTeam = remotelyInsertTeam(members: [self.selfUser])

        XCTAssert(login())
        let teamObserver = TestTeamObserver(team: nil, userSession: userSession!)
        
        // when
        mockTransportSession.performRemoteChanges { (session) in
            session.insertMember(with: self.user1, in: mockTeam)
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(teamObserver.notifications.count, 1)
        guard let memberChange = teamObserver.notifications.last else {
            return XCTFail("no notification received")
        }
        XCTAssertTrue(memberChange.membersChanged)
    }
    
}

// MARK : Remotely Deleted Team

extension TeamTests {

    // See TeamSyncRequestStrategy.skipTeamSync
    func testThatItDeletesAccountIfItsDiscoveredThatTeamHasBeenDeletedDuringSlowSync() {
        XCTAssert(login())
        
        // Given
        // 1. Insert local team, which will not be returned by mock transport when fetching /teams
        let localOnlyTeamId = UUID.create()
        let localOnlyTeam = Team.insertNewObject(in: userSession!.managedObjectContext)
        localOnlyTeam.remoteIdentifier = localOnlyTeamId
        XCTAssert(userSession!.managedObjectContext.saveOrRollback())
        
        // 2. Force a slow sync by returning a 404 when hitting /notifications
        mockTransportSession.responseGeneratorBlock = { request in
            if request.path.hasPrefix("/notifications") && !request.path.contains("cancel_fallback") {
                defer { self.mockTransportSession.responseGeneratorBlock = nil }
                return ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil)
            }
            return nil
        }
        
        // When
        recreateSessionManager() // this will trigger a quick sync
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // Then
        XCTAssertNil(userSession) // user should be logged from the account
        XCTAssertTrue(sessionManager!.accountManager.accounts.isEmpty) // account should be deleted
    }

}
