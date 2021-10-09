

import Foundation

@objc public class ApnsPushTokenStrategy : AbstractRequestStrategy {

    public enum Keys {
        public static let UserClientApnsPushTokenKey = "apnsPushToken"
        static let RequestTypeKey = "requestType"
    }

    public enum RequestType: String {
        case getToken
        case postToken
        case deleteToken
    }


    fileprivate var pushKitTokenSync : ZMUpstreamModifiedObjectSync!
    fileprivate var notificationsTracker: NotificationsTracker?

    var allRequestGenerators : [ZMRequestGenerator] {
        return [pushKitTokenSync]
    }
    
    private var modifySyncFilter: NSPredicate {
        return NSPredicate { object, _ -> Bool in
            guard let o = object as? UserClient, o.apnsPushToken?.isRegistered == false else { return false }
            return true
        }
    }

    private func modifiedPredicate() -> NSPredicate {
        let basePredicate = UserClient.predicateForObjectsThatNeedToBeUpdatedUpstream()
        let nonNilPushToken = NSPredicate(format: "%K != nil", Keys.UserClientApnsPushTokenKey)

        return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, nonNilPushToken])
    }

    @objc public init(withManagedObjectContext managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus?, analytics: AnalyticsType?) {
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        self.pushKitTokenSync = ZMUpstreamModifiedObjectSync(transcoder: self, entityName: UserClient.entityName(), update: modifiedPredicate(), filter: modifySyncFilter, keysToSync: [Keys.UserClientApnsPushTokenKey], managedObjectContext: managedObjectContext)
        if let analytics = analytics {
            self.notificationsTracker = NotificationsTracker(analytics: analytics)
        }
    }

    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        return pushKitTokenSync.nextRequest()
    }

}

extension ApnsPushTokenStrategy: ZMContextChangeTrackerSource {
    public func objectsDidChange(_ object: Set<NSManagedObject>) {

    }

    public func fetchRequestForTrackedObjects() -> NSFetchRequest<NSFetchRequestResult>? {
        return nil
    }

    public func addTrackedObjects(_ objects: Set<NSManagedObject>) {

    }
}

extension ApnsPushTokenStrategy : ZMUpstreamTranscoder {

    public func request(forUpdating managedObject: ZMManagedObject, forKeys keys: Set<String>) -> ZMUpstreamRequest? {
        guard let client = managedObject as? UserClient else { return nil }
        guard client.isSelfClient() else { return nil }
        guard let clientIdentifier = client.remoteIdentifier else { return nil }
        guard let apnsPushToken = client.apnsPushToken else { return nil }

        let request: ZMTransportRequest
        let requestType: RequestType

        if apnsPushToken.isMarkedForDeletion {
            request = ZMTransportRequest(path: "\(PushTokenPath)/\(apnsPushToken.deviceTokenString)", method: .methodDELETE, payload: nil)
            requestType = .deleteToken
        } else if apnsPushToken.isMarkedForDownload {
            request = ZMTransportRequest(path: "\(PushTokenPath)", method: .methodGET, payload: nil)
            requestType = .getToken
        } else if !apnsPushToken.isRegistered {
            let tokenPayload = ApnsPushTokenPayload(pushToken: apnsPushToken, clientIdentifier: clientIdentifier)
            let payload = tokenPayload.asDictionary()
            request = ZMTransportRequest(path: "\(PushTokenPath)", method: .methodPOST, payload: payload as ZMTransportData)
            requestType = .postToken
        } else {
            return nil
        }

        return ZMUpstreamRequest(keys: [Keys.UserClientApnsPushTokenKey], transportRequest: request, userInfo: [Keys.RequestTypeKey : requestType.rawValue])
    }

    public func request(forInserting managedObject: ZMManagedObject, forKeys keys: Set<String>?) -> ZMUpstreamRequest? {
        return nil
    }

    public func updateInsertedObject(_ managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse) {

    }

    public func updateUpdatedObject(_ managedObject: ZMManagedObject, requestUserInfo: [AnyHashable : Any]? = nil, response: ZMTransportResponse, keysToParse: Set<String>) -> Bool {
        guard let client = managedObject as? UserClient else { return false }
        guard client.isSelfClient() else { return false }
        guard let apnsPushToken = client.apnsPushToken else { return false }
        guard let userInfo = requestUserInfo as? [String : String] else { return false }
        guard let requestTypeValue = userInfo[Keys.RequestTypeKey], let requestType = RequestType(rawValue: requestTypeValue) else { return false }

        switch requestType {
        case .postToken:
            var token = apnsPushToken.resetFlags()
            token.isRegistered = true
            client.apnsPushToken = token
            return false
        case .deleteToken:
            // The token might have changed in the meantime, check if it's still up for deletion
            if let token = client.apnsPushToken, token.isMarkedForDeletion {
                client.apnsPushToken = nil
            }
            return false
        case .getToken:
            guard let responseData = response.rawData else { return false }
            guard let payload = try? JSONDecoder().decode([String : [ApnsPushTokenPayload]].self, from: responseData) else { return false }
            guard let tokens = payload["tokens"] else { return false }

            // Find tokens belonging to self client
            let current = tokens.filter { $0.client == client.remoteIdentifier }

            if current.count == 1 && // We found one token
                current[0].token == apnsPushToken.deviceTokenString // It matches what we have locally
            {
                // Clear the flags and we are done
                client.apnsPushToken = apnsPushToken.resetFlags()
                return false
            } else {
                // There is something wrong, local token doesn't match the remotely registered

                // We should remove the local token
                client.apnsPushToken = nil

                notificationsTracker?.registerTokenMismatch()

                // Make sure UI tries to get re-register a new one
                NotificationInContext(name: ZMUserSession.registerCurrentPushTokenNotificationName,
                                      context: managedObjectContext.notificationContext,
                                      object: nil,
                                      userInfo: nil).post()

                return false
            }
        }
    }

    public func objectToRefetchForFailedUpdate(of managedObject: ZMManagedObject) -> ZMManagedObject? {
        return nil
    }

    public var requestGenerators: [ZMRequestGenerator] {
        return []
    }

    public var contextChangeTrackers: [ZMContextChangeTracker] {
        return [self.pushKitTokenSync]
    }

    public func shouldProcessUpdatesBeforeInserts() -> Bool {
        return false
    }

}


public struct ApnsPushTokenPayload: Codable {

    init(pushToken: ApnsPushToken, clientIdentifier: String) {
        token = pushToken.deviceToken
        app = pushToken.appIdentifier
        transport = pushToken.transportType
        client = clientIdentifier
        if #available(iOS 13.3, *) {
            self.ios133 = true
        } else {
            self.ios133 = false
        }
    }
    
    public func asDictionary() -> Dictionary<String, Any> {
        return [
            "token" : token,
            "app": app,
            "transport": transport,
            "client": client,
            "ios133": ios133
        ]
    }

    let token: String
    let app: String
    let transport: String
    let client: String
    let ios133: Bool
}
