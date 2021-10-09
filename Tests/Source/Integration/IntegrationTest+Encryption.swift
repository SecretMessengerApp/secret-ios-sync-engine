//
import WireMockTransport
import XCTest
import WireTesting
import WireCryptobox
import WireDataModel

extension IntegrationTest {
    
    /// Encrypts a message from the given client to the self user.
    /// It will create a session between the two if needed
    @objc(encryptedMessageToSelfWithMessage:fromSender:)
    public func encryptedMessageToSelf(message: ZMGenericMessage, from sender: UserClient) -> Data {
        
        let selfClient = ZMUser.selfUser(in: self.userSession!.syncManagedObjectContext).selfClient()!
        if selfClient.user!.remoteIdentifier == nil {
            selfClient.user!.remoteIdentifier = UUID()
        }
        if selfClient.remoteIdentifier == nil {
            selfClient.remoteIdentifier = NSString.createAlphanumerical() as String
        }
        
        var cypherText: Data?
        self.encryptionContext(for: sender).perform { (session) in
            if !session.hasSession(for: selfClient.sessionIdentifier!) {
                guard let lastPrekey = try? selfClient.keysStore.lastPreKey() else {
                    fatalError("Can't get prekey for self user")
                }
                try! session.createClientSession(selfClient.sessionIdentifier!, base64PreKeyString: lastPrekey)
            }
            
            do {
                cypherText = try session.encrypt(message.data(), for: selfClient.sessionIdentifier!)
            } catch {
                fatalError("Error in encrypting: \(error)")
            }
        }
        return cypherText!
    }
    
    /// Creates a session between the self client to the given user, if it does not
    /// exists already
    @objc(establishSessionFromSelfToClient:)
    public func establishSessionFromSelf(to client: UserClient) {
        
        // this makes sure the client has remote identifier
        _ = self.encryptionContext(for: client)
        
        if client.hasSessionWithSelfClient {
            // done!
            return
        }
        
        let selfClient = ZMUser.selfUser(in: self.userSession!.syncManagedObjectContext).selfClient()!
        var prekey: String?
        self.encryptionContext(for: client).perform { (session) in
            prekey = try! session.generateLastPrekey()
        }
        
        selfClient.keysStore.encryptionContext.perform { (session) in
            try! session.createClientSession(client.sessionIdentifier!, base64PreKeyString: prekey!)
        }
    }
    
    /// Creates a session between the self client, and a client matching a remote client.
    /// If no such client exists locally, it creates it (and the user associated with it).
    @objc(establishSessionFromSelfToRemoteClient:)
    public func establishSessionFromSelf(toRemote remoteClient: MockUserClient) {
        
        guard let remoteUserIdentifierString = remoteClient.user?.identifier,
            let remoteUserIdentifier = UUID(uuidString: remoteUserIdentifierString),
            let remoteClientIdentifier = remoteClient.identifier else {
                fatalError("You should set up remote client with user and identifier")
        }
        
        // create user
        let localUser = ZMUser(remoteID: remoteUserIdentifier, createIfNeeded: true, in: self.userSession!.syncManagedObjectContext)!
        
        // create client
        let localClient = localUser.clients.first(where: { $0.remoteIdentifier == remoteClientIdentifier }) ?? { () -> UserClient in
            let newClient = UserClient.insertNewObject(in: self.userSession!.syncManagedObjectContext)
            newClient.user = localUser
            newClient.remoteIdentifier = remoteClientIdentifier
            return newClient
            }()
        self.userSession!.syncManagedObjectContext.saveOrRollback()
        
        var lastPrekey: String?
        self.mockTransportSession.performRemoteChanges { (session) in
            lastPrekey = remoteClient.lastPrekey.value
        }
        
        let selfClient = ZMUser.selfUser(in: self.userSession!.syncManagedObjectContext).selfClient()!
        if !localClient.hasSessionWithSelfClient {
            XCTAssertTrue(selfClient.establishSessionWithClient(localClient, usingPreKey: lastPrekey!))
        }
    }
    
    /// Decrypts a message that was sent from self to a given user
    public func decryptMessageFromSelf(cypherText: Data, to client: UserClient) -> Data? {
        
        let selfClient = ZMUser.selfUser(in: self.userSession!.syncManagedObjectContext).selfClient()!
        var plainText: Data?
        self.encryptionContext(for: client).perform { (session) in
            if session.hasSession(for: selfClient.sessionIdentifier!) {
                do {
                    plainText = try session.decrypt(cypherText, from: selfClient.sessionIdentifier!)
                } catch {
                    XCTFail("Decryption error: \(error)")
                }
            } else {
                do {
                    plainText = try session.createClientSessionAndReturnPlaintext(for: selfClient.sessionIdentifier!, prekeyMessage: cypherText)
                } catch {
                    XCTFail("Decryption error: \(error)")
                }
            }
        }
        return plainText
    }
}


extension IntegrationTest {
    
    /// Delete all other clients encryption contexts
    public func deleteAllOtherEncryptionContexts() {
        try?  FileManager.default.removeItem(at: self.otherClientsEncryptionContextsURL)
    }
    
    
    /// Returns the folder where the encryption contexts for other test clients are stored
    var otherClientsEncryptionContextsURL: URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("OtherClients")
    }
    
    /// Returns the encryption context to use for a given client. There are extra cryptobox sessions
    /// that simulate a remote client able to decrypt/encrypt data with its own cryptobox instance.
    /// If the client has no remote identifier, it will create one
    fileprivate func encryptionContext(for client: UserClient) -> EncryptionContext {
        if client.remoteIdentifier == nil {
            client.remoteIdentifier = NSString.createAlphanumerical() as String
        }
        let url =  self.otherClientsEncryptionContextsURL.appendingPathComponent("client-\(client.remoteIdentifier!)")
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
        let encryptionContext = EncryptionContext(path: url)
        return encryptionContext
    }
}
