//


import WireTesting
@testable import WireSyncEngine

class TeamDownloadRequestStrategy_EventsTests: MessagingTest {

    var sut: TeamDownloadRequestStrategy!
    var mockApplicationStatus : MockApplicationStatus!
    var mockSyncStatus : MockSyncStatus!
    var mockSyncStateDelegate: MockSyncStateDelegate!
    
    override func setUp() {
        super.setUp()
        mockApplicationStatus = MockApplicationStatus()
        mockSyncStateDelegate = MockSyncStateDelegate()
        mockSyncStatus = MockSyncStatus(managedObjectContext: syncMOC, syncStateDelegate: mockSyncStateDelegate)
        sut = TeamDownloadRequestStrategy(withManagedObjectContext: syncMOC, applicationStatus: mockApplicationStatus, syncStatus: mockSyncStatus)
        
        syncMOC.performGroupedBlockAndWait{
            let user = ZMUser.selfUser(in: self.syncMOC)
            user.remoteIdentifier = self.userIdentifier
            self.syncMOC.saveOrRollback()
        }
    }

    override func tearDown() {
        mockApplicationStatus = nil
        mockSyncStateDelegate = nil
        mockSyncStatus = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Team Create
    // The team.create update event is only sent to the creator of the team

    func testThatItDoesNotCreateALocalTeamWhenReceivingTeamCreateUpdateEvent() {
        // given
        let teamId = UUID.create()
        let payload: [String: Any] = [
            "type": "team.create",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": NSNull()
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        XCTAssertNil(Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil))
    }

    func testThatItDoesNotSetNeedsToBeUpdatedFromBackendForExistingTeamWhenReceivingTeamCreateUpdateEvent() {
        // given
        let teamId = UUID.create()

        syncMOC.performGroupedBlock {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        let payload: [String: Any] = [
            "type": "team.create",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": NSNull()
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        guard let team = Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil) else { return XCTFail("No team created") }
        XCTAssertFalse(team.needsToBeUpdatedFromBackend)
    }

    // MARK: - Team Delete 

    func testThatRequestAccountDeletionWhenReceivingATeamDeleteUpdateEvent() {
        // given
        let teamId = UUID.create()

        syncMOC.performGroupedBlock {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        XCTAssertNotNil(Team.fetch(withRemoteIdentifier: teamId, in: uiMOC))

        let payload: [String: Any] = [
            "type": "team.delete",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": NSNull()
        ]
        
        // expect
        let accountDeletedExpectation = expectation(description: "Account was deleted")
        var token : Any? = PostLoginAuthenticationObserverToken(managedObjectContext: uiMOC) { (event, _) in
            if case WireSyncEngine.PostLoginAuthenticationEvent.accountDeleted = event {
                accountDeletedExpectation.fulfill()
            }
        }
        XCTAssertNotNil(token)

        // when
        processEvent(fromPayload: payload)

        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        token = nil
    }

    func testThatItRequestAccountDeletionWhenReceivingATeamDeleteUpdateEvent() {
        // given
        let conversationId = UUID.create()
        let teamId = UUID.create()

        syncMOC.performGroupedBlock {
            let team = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.remoteIdentifier = conversationId
            conversation.team = team
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))
        XCTAssertNotNil(Team.fetch(withRemoteIdentifier: teamId, in: uiMOC))

        let payload: [String: Any] = [
            "type": "team.delete",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": NSNull()
        ]
        
        let accountDeletedExpectation = expectation(description: "Account was deleted")
        var token : Any? = PostLoginAuthenticationObserverToken(managedObjectContext: uiMOC) { (event, _) in
            if case WireSyncEngine.PostLoginAuthenticationEvent.accountDeleted = event {
                accountDeletedExpectation.fulfill()
            }
        }
        XCTAssertNotNil(token)
        
    
        // when
        processEvent(fromPayload: payload)

        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        token = nil
    }

    // MARK: - Team Update

    func testThatItUpdatesATeamsNameWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let dataPayload = ["name": "Wire GmbH"]

        // when
        guard let team = assertThatItUpdatesTeamsProperties(with: dataPayload) else { return XCTFail("No Team") }

        // then
        XCTAssertEqual(team.name, "Wire GmbH")
    }

    func testThatItUpdatesATeamsIconWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let newAssetId = UUID.create().transportString()
        let dataPayload = ["icon": newAssetId]

        // when
        guard let team = assertThatItUpdatesTeamsProperties(with: dataPayload) else { return XCTFail("No Team") }

        // then
        XCTAssertEqual(team.pictureAssetId, newAssetId)
    }

    func testThatItUpdatesATeamsIconKeyWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let newAssetKey = UUID.create().transportString()
        let dataPayload = ["icon_key": newAssetKey]

        // when
        guard let team = assertThatItUpdatesTeamsProperties(with: dataPayload) else { return XCTFail("No Team") }

        // then
        XCTAssertEqual(team.pictureAssetKey, newAssetKey)
    }

    func assertThatItUpdatesTeamsProperties(
        with dataPayload: [String: Any]?,
        preExistingTeam: Bool = true,
        file: StaticString = #file,
        line: UInt = #line) -> Team? {

        // given
        let teamId = UUID.create()

        if preExistingTeam {
            syncMOC.performGroupedBlock {
                let team = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)!
                team.name = "Some Team"
                team.remoteIdentifier = teamId
                team.pictureAssetId = UUID.create().transportString()
                team.pictureAssetKey = UUID.create().transportString()
                XCTAssert(self.syncMOC.saveOrRollback())
            }

            XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1), file: file, line: line)
            XCTAssertNotNil(Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil))
        }

        let payload: [String: Any] = [
            "type": "team.update",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": dataPayload ?? NSNull()
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        return Team.fetchOrCreate(with: teamId, create: false, in: uiMOC, created: nil)
    }

    func testThatItDoesNotCreateATeamIfItDoesNotAlreadyExistWhenReceivingATeamUpdateUpdateEvent() {
        // given
        let dataPayload = ["name": "Wire GmbH"]

        // then
        XCTAssertNil(assertThatItUpdatesTeamsProperties(with: dataPayload, preExistingTeam: false))
    }

    // MARK: - Team Member-Join

    func testThatItAddsANewTeamMemberAndUserWhenReceivingATeamMemberJoinUpdateEventExistingTeam() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlock {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)!
            XCTAssert(self.syncMOC.saveOrRollback())
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: uiMOC) else { return XCTFail("No user") }
        guard let team = Team.fetch(withRemoteIdentifier: teamId, in: uiMOC) else { return XCTFail("No team") }
        guard let member = user.membership else { return XCTFail("No member") }

        XCTAssert(user.needsToBeUpdatedFromBackend)
        XCTAssert(member.needsToBeUpdatedFromBackend)
        XCTAssertFalse(team.needsToBeUpdatedFromBackend)
        XCTAssertFalse(team.needsToRedownloadMembers)
        XCTAssertEqual(member.team, team)
    }

    func testThatItAddsANewTeamMemberToAnExistingUserWhenReceivingATeamMemberJoinUpdateEventExistingTeam() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlockAndWait {
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No user") }
            guard let team = Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) else { return XCTFail("No team") }
            guard let member = user.membership else { return XCTFail("No member") }

            XCTAssert(user.needsToBeUpdatedFromBackend)
            XCTAssert(member.needsToBeUpdatedFromBackend)
            XCTAssertFalse(team.needsToBeUpdatedFromBackend)
            XCTAssertFalse(team.needsToRedownloadMembers)
            XCTAssertEqual(member.team, team)
        }
    }

    func testThatItAddsANewTeamMemberAndUserToAnExistingUserWhenReceivingATeamMemberJoinUpdateEventExistingTeam() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlockAndWait {
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No user") }
            guard let team = Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) else { return XCTFail("No team") }
            guard let member = user.membership else { return XCTFail("No member") }

            XCTAssert(user.needsToBeUpdatedFromBackend)
            XCTAssert(member.needsToBeUpdatedFromBackend)
            XCTAssertFalse(team.needsToBeUpdatedFromBackend)
            XCTAssertFalse(team.needsToRedownloadMembers)
            XCTAssertEqual(member.team, team)
        }
    }

    func testThatItDoesNotCreateALocalTeamWhenReceivingAMemberJoinEventForTheSelfUserWithoutExistingTeam() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNil(ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC))
            XCTAssertNil(Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC))
        }
    }

    func testThatItFlagsAddedTeamMembersToBeRefetchedWhenItReceivesAMemberJoinForTheSelfUserEvenIfThereWasALocalTeam() {
        // given
        let teamId = UUID.create()
        var userId: UUID!

        syncMOC.performGroupedBlockAndWait {
            let user = ZMUser.selfUser(in: self.syncMOC)
            userId = user.remoteIdentifier
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        let payload: [String: Any] = [
            "type": "team.member-join",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let team = Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) else { return XCTFail("No team") }
            XCTAssertFalse(team.needsToRedownloadMembers)
            guard let member = Member.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No member") }
            XCTAssert(member.needsToBeUpdatedFromBackend)
        }
    }

    // MARK: - Team Member-Leave

    func testThatItDeletesAMemberWhenReceivingATeamMemberLeaveUpdateEventForAnotherUser() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlock {
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            XCTAssertNotNil(member)
            XCTAssertEqual(user.membership, member)
            XCTAssert(self.syncMOC.saveOrRollback())
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))

        let payload: [String: Any] = [
            "type": "team.member-leave",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNotNil(ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC))

            // users won't be deleted as we might be in other (non-team) conversations with them
            guard let team = Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) else { return XCTFail("No team") }
            XCTAssertEqual(team.members, [])
        }
    }

    func testThatItRequestAccountDeletionWhenReceivingATeamMemberLeaveUpdateEventForSelfUser() {
        let teamId = UUID.create()
        var userId: UUID!

        syncMOC.performGroupedBlockAndWait {
            // given
            let user = ZMUser.selfUser(in: self.syncMOC)
            userId = user.remoteIdentifier!
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            XCTAssertNotNil(member)
            XCTAssertEqual(user.membership, member)
        }
        
        // expect
        let accountDeletedExpectation = expectation(description: "Account was deleted")
        var token : Any? = PostLoginAuthenticationObserverToken(managedObjectContext: uiMOC) { (event, _) in
            if case WireSyncEngine.PostLoginAuthenticationEvent.accountDeleted = event {
                accountDeletedExpectation.fulfill()
            }
        }
        XCTAssertNotNil(token)

        // when
        let payload: [String: Any] = [
            "type": "team.member-leave",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]
        processEvent(fromPayload: payload)

        // then
        XCTAssertTrue(waitForCustomExpectations(withTimeout: 0.5))
        token = nil
    }

    func testThatItRemovesAMemberFromAllGroupConversationsSheWasPartOfWhenReceivingAMemberLeaveForThatMember() {
        let teamId = UUID.create()
        let teamConversationId = UUID.create(), conversationId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlockAndWait {
            // given
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = .create()
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            let teamConversation1 = ZMConversation.insertNewObject(in: self.syncMOC)
            teamConversation1.remoteIdentifier = teamConversationId
            teamConversation1.conversationType = .group
            teamConversation1.internalAddParticipants([user])
            teamConversation1.team = team
            let conversation = ZMConversation.insertGroupConversation(into: self.syncMOC, withParticipants: [user, otherUser])
            conversation?.remoteIdentifier = conversationId
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            XCTAssertNotNil(member)
            XCTAssertEqual(user.membership, member)
        }

        // when
        let payload: [String: Any] = [
            "type": "team.member-leave",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]
        processEvent(fromPayload: payload)

        // then
        syncMOC.performGroupedBlockAndWait {
            guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No User") }
            guard Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) != nil else { return XCTFail("No User") }
            XCTAssertNil(user.membership)
            guard let teamConversation = ZMConversation.fetch(withRemoteIdentifier: teamConversationId, in: self.syncMOC) else { return XCTFail("No Team Conversation") }
            guard let conversation = ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC) else { return XCTFail("No Conversation") }
            XCTAssertFalse(teamConversation.lastServerSyncedActiveParticipants.contains(user))
            XCTAssertFalse(conversation.lastServerSyncedActiveParticipants.contains(user))
        }
    }
    
    func testThatItAppendsASystemMessageToAllTeamConversationsSheWasPartOfWhenReceivingAMemberLeaveForThatMember() {
        let teamId = UUID.create()
        let teamConversationId = UUID.create(), teamAnotherConversationId = UUID.create(), conversationId = UUID.create()
        let userId = UUID.create()
        
        syncMOC.performGroupedBlockAndWait {
            // given
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = .create()
            
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            
            let teamConversation1 = ZMConversation.insertNewObject(in: self.syncMOC)
            teamConversation1.remoteIdentifier = teamConversationId
            teamConversation1.conversationType = .group
            teamConversation1.internalAddParticipants([user])
            teamConversation1.team = team
            
            let teamConversation2 = ZMConversation.insertNewObject(in: self.syncMOC)
            teamConversation2.remoteIdentifier = teamAnotherConversationId
            teamConversation2.conversationType = .group
            teamConversation2.internalAddParticipants([user])
            teamConversation2.team = team

            
            let conversation = ZMConversation.insertGroupConversation(into: self.syncMOC, withParticipants: [user, otherUser])
            conversation?.remoteIdentifier = conversationId
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            XCTAssertNotNil(member)
            XCTAssertEqual(user.membership, member)
        }
        
        // when
        let timestamp = Date(timeIntervalSinceNow: -30)
        let payload: [String: Any] = [
            "type": "team.member-leave",
            "team": teamId.transportString(),
            "time": timestamp.transportString(),
            "data": ["user" : userId.transportString()]
        ]
        processEvent(fromPayload: payload)
        
        // then
        syncMOC.performGroupedBlockAndWait {
            guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: self.syncMOC) else { return XCTFail("No User") }
            guard Team.fetch(withRemoteIdentifier: teamId, in: self.syncMOC) != nil else { return XCTFail("No User") }
            XCTAssertNil(user.membership)
            guard let teamConversation = ZMConversation.fetch(withRemoteIdentifier: teamConversationId, in: self.syncMOC) else { return XCTFail("No Team Conversation") }
            guard let teamAnotherConversation = ZMConversation.fetch(withRemoteIdentifier: teamAnotherConversationId, in: self.syncMOC) else { return XCTFail("No Team Conversation") }
            guard let conversation = ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC) else { return XCTFail("No Conversation") }
            
            self.checkLastMessage(in: teamConversation, isLeaveMessageFor: user, at: timestamp)
            self.checkLastMessage(in: teamAnotherConversation, isLeaveMessageFor: user, at: timestamp)
            
            if let lastMessage = conversation.lastMessage as? ZMSystemMessage, lastMessage.systemMessageType == .teamMemberLeave {
                XCTFail("Should not append leave message to regular conversation")
            }
        }
    }
    
    private func checkLastMessage(in conversation: ZMConversation, isLeaveMessageFor user: ZMUser, at timestamp: Date,  file: StaticString = #file, line: UInt = #line) {
        guard let lastMessage = conversation.lastMessage as? ZMSystemMessage else { XCTFail("Last message is not system message", file: file, line: line); return }
        guard lastMessage.systemMessageType == .teamMemberLeave else { XCTFail("System message is not teamMemberLeave: but '\(lastMessage.systemMessageType.rawValue)'", file: file, line: line); return }
        guard let serverTimestamp = lastMessage.serverTimestamp else { XCTFail("System message should have timestamp", file: file, line: line); return }
        XCTAssertEqual(serverTimestamp.timeIntervalSince1970, timestamp.timeIntervalSince1970, accuracy: 0.1, file: file, line:line)
        return
    }

    // MARK: - Team Member-Update

    func testThatItFlagsAmemberTobeUpdatedFromTheBackendWhenReceivingTeamMemberUpdateEvent() {
        // given
        let teamId = UUID.create()
        let userId = UUID.create()

        syncMOC.performGroupedBlock {
            let team = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)!
            let user = ZMUser(remoteID: userId, createIfNeeded: true, in: self.syncMOC)!
            user.needsToBeUpdatedFromBackend = false
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            XCTAssertFalse(member.needsToBeUpdatedFromBackend)
            XCTAssert(self.syncMOC.saveOrRollback())
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.1))

        let payload: [String: Any] = [
            "type": "team.member-update",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["user" : userId.transportString()]
        ]

        // when
        processEvent(fromPayload: payload)

        // then
        guard let user = ZMUser.fetch(withRemoteIdentifier: userId, in: uiMOC) else { return XCTFail("No user") }
        guard let team = Team.fetch(withRemoteIdentifier: teamId, in: uiMOC) else { return XCTFail("No team") }
        guard let member = user.membership else { return XCTFail("No member") }

        XCTAssertFalse(user.needsToBeUpdatedFromBackend)
        XCTAssert(member.needsToBeUpdatedFromBackend)
        XCTAssertFalse(team.needsToBeUpdatedFromBackend)
        XCTAssertFalse(team.needsToRedownloadMembers)
        XCTAssertEqual(member.team, team)
    }
    
    // MARK: - Team Conversation-Create
    
    func testThatItIgnoresTeamConversationCreateUpdateEvent() {
        // given
        let conversationId = UUID.create()
        let teamId = UUID.create()
        
        syncMOC.performGroupedBlockAndWait {
            _ = Team.fetchOrCreate(with: teamId, create: true, in: self.syncMOC, created: nil)
        }
        
        let payload: [String: Any] = [
            "type": "team.conversation-create",
            "team": teamId.transportString(),
            "time": Date().transportString(),
            "data": ["conv": conversationId.transportString()]
        ]
        
        // when
        processEvent(fromPayload: payload)
        
        // then
        syncMOC.performGroupedBlockAndWait {
            XCTAssertNil(ZMConversation.fetch(withRemoteIdentifier: conversationId, in: self.syncMOC))
        }
    }

    // MARK: - Helper

    private func processEvent(fromPayload eventPayload: [String: Any], file: StaticString = #file, line: UInt = #line) {
        guard let event = ZMUpdateEvent(fromEventStreamPayload: eventPayload as ZMTransportData, uuid: nil) else {
            return XCTFail("Unable to create update event from payload", file: file, line: line)
        }

        // when
        syncMOC.performGroupedBlock {
            self.sut.processEvents([event], liveEvents: false, prefetchResult: nil)
            XCTAssert(self.syncMOC.saveOrRollback(), file: file, line: line)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5), file: file, line: line)
    }

}
