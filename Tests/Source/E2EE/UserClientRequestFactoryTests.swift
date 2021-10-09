//


import WireSyncEngine
import WireUtilities
import WireTesting
import WireCryptobox
import WireMockTransport
import WireDataModel

class UserClientRequestFactoryTests: MessagingTest {
    
    var sut: UserClientRequestFactory!
    var authenticationStatus: ZMAuthenticationStatus!
    var spyKeyStore: SpyUserClientKeyStore!
    var userInfoParser: MockUserInfoParser!
    
    override func setUp() {
        super.setUp()
        self.spyKeyStore = SpyUserClientKeyStore(accountDirectory: accountDirectory, applicationContainer: sharedContainerURL)
        self.userInfoParser = MockUserInfoParser()
        self.authenticationStatus = MockAuthenticationStatus(userInfoParser: self.userInfoParser)
        self.sut = UserClientRequestFactory(keysStore: self.spyKeyStore)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: spyKeyStore.cryptoboxDirectory)
        self.authenticationStatus = nil
        self.sut = nil
        self.spyKeyStore = nil
        self.userInfoParser = nil
        super.tearDown()
    }

    func expectedKeyPayloadForClientPreKeys(_ client : UserClient) -> [[String : Any]] {
        let generatedKeys = self.spyKeyStore.lastGeneratedKeys
        let expectedPrekeys : [[String: Any]] = generatedKeys.map { (key: (id: UInt16, prekey: String)) in
            return ["key": key.prekey, "id": NSNumber(value: key.id)]
        }
        return expectedPrekeys
    }
    
    func testThatItCreatesRegistrationRequestWithEmailCorrectly() {
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        let credentials = ZMEmailCredentials(email: "some@example.com", password: "123")
        
        //when
        guard let request = try? sut.registerClientRequest(client, credentials: credentials, cookieLabel: "mycookie") else {
            XCTFail()
            return
        }
        
        //then
        guard let transportRequest = request.transportRequest else { return XCTFail("Should return non nil request") }
        guard let payload = transportRequest.payload?.asDictionary() as? [String: NSObject] else { return XCTFail("Request should contain payload") }
        
        guard let type = payload["type"] as? String, type == DeviceType.permanent.rawValue else { return XCTFail("Client type should be 'permanent'") }
        guard let password = payload["password"] as? String, password == credentials.password else { return XCTFail("Payload should contain password") }
        
        guard let lastPreKey = self.spyKeyStore.lastGeneratedLastPrekey else {
            XCTFail()
            return
        }
        
        guard let lastKeyPayload = payload["lastkey"] as? [String: Any] else { return XCTFail() }
        XCTAssertEqual(lastKeyPayload["key"] as? String, lastPreKey)
        XCTAssertEqual(lastKeyPayload["id"] as? NSNumber, NSNumber(value: CBOX_LAST_PREKEY_ID))

        guard let preKeysPayloadData = payload["prekeys"] as? [[String: Any]] else  { return XCTFail("Payload should contain prekeys") }
        zip(preKeysPayloadData, expectedKeyPayloadForClientPreKeys(client)).forEach { (lhs, rhs) in
            XCTAssertEqual(lhs["key"] as? String, rhs["key"] as? String)
            XCTAssertEqual(lhs["id"] as? UInt16, rhs["id"] as? UInt16)
        }

        guard let apnsKeysPayload = payload["sigkeys"] as? [String: NSObject] else {return XCTFail("Payload should contain apns keys")}
        XCTAssertNotNil(apnsKeysPayload["enckey"], "Payload should contain apns enc key")
        XCTAssertNotNil(apnsKeysPayload["mackey"], "Payload should contain apns mac key")
    }
    
    func testThatItCreatesRegistrationRequestWithPhoneCredentialsCorrectly() {
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        
        //when
        let upstreamRequest : ZMUpstreamRequest
        do {
            upstreamRequest = try sut.registerClientRequest(client, credentials: nil, cookieLabel: "mycookie")
        } catch {
            return XCTFail("error should be nil \(error)")
            
        }
        
        //then
        guard let request = upstreamRequest.transportRequest else { return XCTFail("Request should not be nil") }
        XCTAssertEqual(request.path, "/clients", "Should create request with correct path")
        XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST, "Should create POST request")
        guard let payload = request.payload?.asDictionary() as? [String: NSObject] else { return XCTFail("Request should contain payload") }
        XCTAssertEqual(payload["type"] as? String, DeviceType.permanent.rawValue, "Client type should be 'permanent'")
        XCTAssertNil(payload["password"])
        
        let lastPreKey = try! self.spyKeyStore.lastPreKey()
        
        guard let lastKeyPayload = payload["lastkey"] as? [String: Any] else { return XCTFail("Payload should contain last prekey") }
        XCTAssertEqual(lastKeyPayload["key"] as? String, lastPreKey)
        XCTAssertEqual(lastKeyPayload["id"] as? NSNumber, NSNumber(value: CBOX_LAST_PREKEY_ID))
        
        guard let preKeysPayloadData = payload["prekeys"] as? [[String: Any]] else { return XCTFail("Payload should contain prekeys") }
        
        zip(preKeysPayloadData, expectedKeyPayloadForClientPreKeys(client)).forEach { (lhs, rhs) in
            XCTAssertEqual(lhs["key"] as? String, rhs["key"] as? String)
            XCTAssertEqual(lhs["id"] as? UInt16, rhs["id"] as? UInt16)
        }

        guard let signalingKeys = payload["sigkeys"] as? [String: NSObject] else { return XCTFail("Payload should contain apns keys") }
        XCTAssertNotNil(signalingKeys["enckey"], "Payload should contain apns enc key")
        XCTAssertNotNil(signalingKeys["mackey"], "Payload should contain apns mac key")
    }
    
    func testThatItReturnsNilForRegisterClientRequestIfCanNotGeneratePreKyes() {
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        self.spyKeyStore.failToGeneratePreKeys = true
        
        let credentials = ZMEmailCredentials(email: "some@example.com", password: "123")
        
        //when
        let request = try? sut.registerClientRequest(client, credentials: credentials, cookieLabel: "mycookie")
        
        XCTAssertNil(request, "Should not return request if client fails to generate prekeys")
    }
    
    func testThatItReturnsNilForRegisterClientRequestIfCanNotGenerateLastPreKey() {
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        self.spyKeyStore.failToGenerateLastPreKey = true
        
        let credentials = ZMEmailCredentials(email: "some@example.com", password: "123")
        
        //when
        let request = try? sut.registerClientRequest(client, credentials: credentials, cookieLabel: "mycookie")
        
        XCTAssertNil(request, "Should not return request if client fails to generate last prekey")
    }
    
    func testThatItCreatesUpdateClientRequestCorrectlyWhenStartingFromPrekey0() {
        
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        client.remoteIdentifier = UUID.create().transportString()
        
        //when
        let request = try! sut.updateClientPreKeysRequest(client)
        
        AssertOptionalNotNil(request.transportRequest, "Should return non nil request") { request in
            
            XCTAssertEqual(request.path, "/clients/\(client.remoteIdentifier!)", "Should create request with correct path")
            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPUT, "Should create POST request")
            
            AssertOptionalNotNil(request.payload?.asDictionary() as? [String: NSObject], "Request should contain payload") { payload in
                
                let preKeysPayloadData = payload["prekeys"] as? [[NSString: Any]]
                AssertOptionalNotNil(preKeysPayloadData, "Payload should contain prekeys") { data in
                    zip(data, expectedKeyPayloadForClientPreKeys(client)).forEach { (lhs, rhs) in
                        XCTAssertEqual(lhs["key"] as? String, rhs["key"] as? String)
                        XCTAssertEqual(lhs["id"] as? UInt16, rhs["id"] as? UInt16)
                    }
                }
            }
        }
    }
    
    func testThatItCreatesUpdateClientRequestCorrectlyWhenStartingFromPrekey400() {
        
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        client.remoteIdentifier = UUID.create().transportString()
        client.preKeysRangeMax = 400
        
        //when
        let request = try! sut.updateClientPreKeysRequest(client)
        
        AssertOptionalNotNil(request.transportRequest, "Should return non nil request") { request in
            
            XCTAssertEqual(request.path, "/clients/\(client.remoteIdentifier!)", "Should create request with correct path")
            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPUT, "Should create POST request")
            
            AssertOptionalNotNil(request.payload?.asDictionary() as? [String: NSObject], "Request should contain payload") { payload in
                
                let preKeysPayloadData = payload["prekeys"] as? [[NSString: Any]]
                AssertOptionalNotNil(preKeysPayloadData, "Payload should contain prekeys") { data in
                    zip(data, expectedKeyPayloadForClientPreKeys(client)).forEach { (lhs, rhs) in
                        XCTAssertEqual(lhs["key"] as? String, rhs["key"] as? String)
                        XCTAssertEqual(lhs["id"] as? UInt16, rhs["id"] as? UInt16)
                    }
                }
            }
        }
    }

    
    func testThatItReturnsNilForUpdateClientRequestIfCanNotGeneratePreKeys() {
        
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        self.spyKeyStore.failToGeneratePreKeys = true

        client.remoteIdentifier = UUID.create().transportString()
        
        //when
        let request = try? sut.updateClientPreKeysRequest(client)
        
        XCTAssertNil(request, "Should not return request if client fails to generate prekeys")
    }
    
    func testThatItDoesNotReturnRequestIfClientIsNotSynced() {
        //given
        let client = UserClient.insertNewObject(in: self.syncMOC)
        
        // when
        do {
            _ = try sut.updateClientPreKeysRequest(client)
        }
        catch let error {
            XCTAssertNotNil(error, "Should not return request if client does not have remoteIdentifier")
        }
        
    }
    
    func testThatItCreatesARequestToDeleteAClient() {
        
        // given
        let email = "foo@example.com"
        let password = "gfsgdfgdfgdfgdfg"
        let credentials = ZMEmailCredentials(email: email, password: password)
        let client = UserClient.insertNewObject(in: self.syncMOC)
        client.remoteIdentifier = "\(client.objectID)"
        self.syncMOC.saveOrRollback()
        
        // when
        let nextRequest = sut.deleteClientRequest(client, credentials: credentials)
        
        // then
        AssertOptionalNotNil(nextRequest) {
            XCTAssertEqual($0.transportRequest.path, "/clients/\(client.remoteIdentifier!)")
            XCTAssertEqual($0.transportRequest.payload as! [String:String], [
                "email" : email,
                "password" : password
                ])
            XCTAssertEqual($0.transportRequest.method, ZMTransportRequestMethod.methodDELETE)
        }
    }
    
}

