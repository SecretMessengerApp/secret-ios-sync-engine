//

import Foundation

extension ZMContextChangeTrackerSource {
    func notifyChangeTrackers(_ client : UserClient) {
        contextChangeTrackers.forEach{$0.objectsDidChange(Set(arrayLiteral:client))}
    }
}


class RequestStrategyTestBase : MessagingTest {
        
    func createRemoteClient() -> UserClient {
        
        var mockUserIdentifier: String!
        var mockClientIdentifier: String!
        
        self.mockTransportSession.performRemoteChanges { (session) -> Void in
            let mockUser = session.insertUser(withName: "foo")
            let mockClient = session.registerClient(for: mockUser, label: mockUser.name!, type: "permanent", deviceClass: "phone")
            mockClientIdentifier = mockClient.identifier
            mockUserIdentifier = mockUser.identifier
        }

        let client = UserClient.insertNewObject(in: self.syncMOC)
        client.remoteIdentifier = mockClientIdentifier
        let user = ZMUser.insertNewObject(in: self.syncMOC)
        user.remoteIdentifier = UUID(uuidString: mockUserIdentifier)
        client.user = user
        
        return client
    }
}

