//

import XCTest

class AvailabilityTests: IntegrationTest {
    
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
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testThatAvailabilityIsBroadcastedWhenChanged() {
        // given
        XCTAssertTrue(login())
        mockTransportSession.resetReceivedRequests()
        let selfUser = ZMUser.selfUser(inUserSession: self.userSession!)
        let client1 = user1.clients.anyObject() as! MockUserClient
        let client2 = user2.clients.anyObject() as! MockUserClient
        
        // when
        userSession?.performChanges {
            selfUser.availability = .busy
        }
        XCTAssertTrue(selfUser.modifiedKeys!.contains(AvailabilityKey))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let expectedRequests = ["/broadcast/otr/messages",                                      // attempt broadcast status (server responds with missing clients)
                                "/users/prekeys",                                               // establish sessions with missing clients
                                "/users/\(user1.identifier)/clients/\(client1.identifier!)",    // fetch client details
                                "/users/\(user2.identifier)/clients/\(client2.identifier!)",    // fetch client details
                                "/broadcast/otr/messages"]                                      // broadcast status
        
        
        
        XCTAssertNil(selfUser.modifiedKeys)
        XCTAssertEqual(expectedRequests.count, mockTransportSession.receivedRequests().count)
        XCTAssertEqual(Set(expectedRequests), Set(mockTransportSession.receivedRequests().map({ $0.path })))
    }
    
    func testThatAvailabilityIsBroadcastedToAllConnectedUsersAndTeamMembers() {
        // given
        _ = remotelyInsertTeam(members: [self.selfUser, self.user3, self.user4])
        
        XCTAssertTrue(login())
        mockTransportSession.resetReceivedRequests()
        let selfUser = ZMUser.selfUser(inUserSession: self.userSession!)
        
        // when
        userSession?.performChanges {
            selfUser.availability = .away
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        let request = mockTransportSession.receivedRequests().last!
        let message = ZMNewOtrMessage.parse(from: request.binaryData)
        let connectedAndTeamMemberUUIDs = [user1, user2, user3, user4].compactMap { user(for: $0)?.remoteIdentifier }
        let recipientsUUIDs = message!.recipients.compactMap ({ $0.user.uuid.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) in NSUUID(uuidBytes: bytes) as UUID
        }) })
        
        XCTAssertEqual(Set(connectedAndTeamMemberUUIDs), Set(recipientsUUIDs))
    }
    
}
