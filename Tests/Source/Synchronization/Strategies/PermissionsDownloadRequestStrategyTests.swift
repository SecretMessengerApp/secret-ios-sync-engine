//


import WireTesting
@testable import WireSyncEngine


class PermissionsDownloadRequestStrategyTests: MessagingTest {

    var sut: PermissionsDownloadRequestStrategy!
    var mockApplicationStatus: MockApplicationStatus!

    override func setUp() {
        super.setUp()
        mockApplicationStatus = MockApplicationStatus()
        sut = PermissionsDownloadRequestStrategy(withManagedObjectContext: syncMOC, applicationStatus: mockApplicationStatus)
    }

    override func tearDown() {
        mockApplicationStatus = nil
        sut = nil
        super.tearDown()
    }

    func testThatItDoesNotGenerateARequestInitially() {
        XCTAssertNil(sut.nextRequest())
    }

    func testThatItDoesNotCreateARequestIfThereIsNoMemberToBeRedownloaded() {
        syncMOC.performGroupedBlockAndWait {
            // given
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
            let member = Member.insertNewObject(in: self.syncMOC)
            member.remoteIdentifier = .create()

            // when
            member.needsToBeUpdatedFromBackend = false
            self.boostrapChangeTrackers(with: member)

            // then
            XCTAssertNil(self.sut.nextRequest())
        }
    }

    func testThatItCreatesAReuqestForAMemberThatNeedsToBeRedownloadItsMembersFromTheBackend() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let teamId = UUID.create(), userId = UUID.create()
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = teamId
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userId
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)

            // when
            member.needsToBeUpdatedFromBackend = true
            self.boostrapChangeTrackers(with: member)

            // then
            guard let request = self.sut.nextRequest() else { return XCTFail("No request generated") }
            XCTAssertEqual(request.method, .methodGET)
            XCTAssertEqual(request.path, "/teams/\(teamId.transportString())/members/\(userId.transportString())")
        }
    }

    func testThatItDoesNotCreateARequestDuringSync() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let member = Member.insertNewObject(in: self.syncMOC)
            member.remoteIdentifier = .create()
            self.mockApplicationStatus.mockSynchronizationState = .synchronizing

            // when
            member.needsToBeUpdatedFromBackend = true
            self.boostrapChangeTrackers(with: member)

            // then
            XCTAssertNil(self.sut.nextRequest())
        }
    }

    func testThatItUpdatesAMembersPermissionsWithTheResponse() {
        var member: Member!
        var user: ZMUser!

        syncMOC.performGroupedBlock {
            // given
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
            let team = Team.insertNewObject(in: self.syncMOC)
            team.remoteIdentifier = .create()
            user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = .create()
            member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)

            member.needsToBeUpdatedFromBackend = true
            self.boostrapChangeTrackers(with: member)
            guard let request = self.sut.nextRequest() else { return XCTFail("No request generated") }

            // when
            let payload: [String: Any] = [
                "user": user.remoteIdentifier!.transportString(),
                "permissions": ["self": 17, "copy": 0]
            ]

            let response = ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil)

            // when
            request.complete(with: response)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.2))

        syncMOC.performGroupedBlockAndWait {
            // then
            XCTAssertFalse(member.needsToBeUpdatedFromBackend)
            XCTAssertEqual(member.permissions, [.createConversation, .addRemoveConversationMember])
            XCTAssertEqual(member.user, user)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.2))

        syncMOC.performGroupedBlockAndWait {
            // then
            self.boostrapChangeTrackers(with: member)
            XCTAssertNil(self.sut.nextRequestIfAllowed())
        }
    }


    func testThatItDeletesALocalMemberWhenReceivingA404() {
        let userid = UUID.create()

        syncMOC.performGroupedBlock {
            // given
            let team = Team.insertNewObject(in: self.syncMOC)
            self.mockApplicationStatus.mockSynchronizationState = .eventProcessing
            team.remoteIdentifier = .create()
            let user = ZMUser.insertNewObject(in: self.syncMOC)
            user.remoteIdentifier = userid
            let member = Member.getOrCreateMember(for: user, in: team, context: self.syncMOC)
            member.needsToBeUpdatedFromBackend = true

            self.boostrapChangeTrackers(with: member)
            guard let request = self.sut.nextRequest() else { return XCTFail("No request generated") }

            // when
            let response = ZMTransportResponse(payload: [] as ZMTransportData, httpStatus: 404, transportSessionError: nil)

            // when
            request.complete(with: response)
        }

        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.2))

        syncMOC.performGroupedBlockAndWait {
            // then
            XCTAssertNil(Member.fetch(withRemoteIdentifier: userid, in: self.syncMOC))
        }
    }
    
    // MARK: - Helper
    
    private func boostrapChangeTrackers(with objects: ZMManagedObject...) {
        sut.contextChangeTrackers.forEach {
            $0.objectsDidChange(Set(objects))
        }
        
    }
    
}
