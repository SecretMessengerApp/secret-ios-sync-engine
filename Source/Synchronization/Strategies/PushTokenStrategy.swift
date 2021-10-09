//

import Foundation
import WireDataModel

let VoIPIdentifierSuffix = "-voip"
let TokenKey = "token"
let PushTokenPath = "/push/tokens"


extension ZMSingleRequestSync : ZMRequestGenerator {}

@objc public class PushTokenStrategy : AbstractRequestStrategy {

    enum Keys {
        static let UserClientPushTokenKey = "pushToken"
        static let RequestTypeKey = "requestType"
    }

    enum RequestType: String {
        case getToken
        case postToken
        case deleteToken
    }


    fileprivate var pushKitTokenSync : ZMUpstreamModifiedObjectSync!
    fileprivate var notificationsTracker: NotificationsTracker?

    var allRequestGenerators : [ZMRequestGenerator] {
        return [pushKitTokenSync]
    }

    private func modifiedPredicate() -> NSPredicate {
        let basePredicate = UserClient.predicateForObjectsThatNeedToBeUpdatedUpstream()
        let nonNilPushToken = NSPredicate(format: "%K != nil", Keys.UserClientPushTokenKey)

        return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, nonNilPushToken])
    }
    
    private var modifySyncFilter: NSPredicate {
        return NSPredicate { object, _ -> Bool in
            guard let o = object as? UserClient, o.pushToken?.isRegistered == false else { return false }
            return true
        }
    }

    @objc public init(withManagedObjectContext managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus?, analytics: AnalyticsType?) {
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        self.pushKitTokenSync = ZMUpstreamModifiedObjectSync(transcoder: self, entityName: UserClient.entityName(), update: modifiedPredicate(), filter: modifySyncFilter, keysToSync: [Keys.UserClientPushTokenKey], managedObjectContext: managedObjectContext)
        if let analytics = analytics {
            self.notificationsTracker = NotificationsTracker(analytics: analytics)
        }
    }

    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        return pushKitTokenSync.nextRequest()
    }

}

extension PushTokenStrategy: ZMContextChangeTrackerSource {
    public func objectsDidChange(_ object: Set<NSManagedObject>) {

    }

    public func fetchRequestForTrackedObjects() -> NSFetchRequest<NSFetchRequestResult>? {
        return nil
    }

    public func addTrackedObjects(_ objects: Set<NSManagedObject>) {

    }
}

extension PushTokenStrategy : ZMUpstreamTranscoder {

    public func request(forUpdating managedObject: ZMManagedObject, forKeys keys: Set<String>) -> ZMUpstreamRequest? {
        guard let client = managedObject as? UserClient else { return nil }
        guard client.isSelfClient() else { return nil }
        guard let clientIdentifier = client.remoteIdentifier else { return nil }
        guard let pushToken = client.pushToken else { return nil }

        let request: ZMTransportRequest
        let requestType: RequestType

        if pushToken.isMarkedForDeletion {
            request = ZMTransportRequest(path: "\(PushTokenPath)/\(pushToken.deviceTokenString)", method: .methodDELETE, payload: nil)
            requestType = .deleteToken
        } else if pushToken.isMarkedForDownload {
            request = ZMTransportRequest(path: "\(PushTokenPath)", method: .methodGET, payload: nil)
            requestType = .getToken
        } else if !pushToken.isRegistered || !pushToken.isiOS13Registered || !pushToken.isUpdateiOS13 {
            let tokenPayload = PushTokenPayload(pushToken: pushToken, clientIdentifier: clientIdentifier)
            let payload = tokenPayload.asDictionary()
            request = ZMTransportRequest(path: "\(PushTokenPath)", method: .methodPOST, payload: payload as ZMTransportData?)
            requestType = .postToken
        } else {
            return nil
        }

        return ZMUpstreamRequest(keys: [Keys.UserClientPushTokenKey], transportRequest: request, userInfo: [Keys.RequestTypeKey : requestType.rawValue])
    }

    public func request(forInserting managedObject: ZMManagedObject, forKeys keys: Set<String>?) -> ZMUpstreamRequest? {
        return nil
    }

    public func updateInsertedObject(_ managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse) {

    }

    public func updateUpdatedObject(_ managedObject: ZMManagedObject, requestUserInfo: [AnyHashable : Any]? = nil, response: ZMTransportResponse, keysToParse: Set<String>) -> Bool {
        guard let client = managedObject as? UserClient else { return false }
        guard client.isSelfClient() else { return false }
        guard let pushToken = client.pushToken else { return false }
        guard let userInfo = requestUserInfo as? [String : String] else { return false }
        guard let requestTypeValue = userInfo[Keys.RequestTypeKey], let requestType = RequestType(rawValue: requestTypeValue) else { return false }

        switch requestType {
        case .postToken:
            var token = pushToken.resetFlags()
            token.isRegistered = true
            token.isiOS13Registered = true
            if #available(iOS 13.3, *) {
                token.isUpdateiOS13 = true
            }
            client.pushToken = token
            return false
        case .deleteToken:
            // The token might have changed in the meantime, check if it's still up for deletion
            if let token = client.pushToken, token.isMarkedForDeletion {
                client.pushToken = nil
            }
            return false
        case .getToken:
            guard let responseData = response.rawData else { return false }
            guard let payload = try? JSONDecoder().decode([String : [PushTokenPayload]].self, from: responseData) else { return false }
            guard let tokens = payload["tokens"] else { return false }

            // Find tokens belonging to self client
            let current = tokens.filter { $0.client == client.remoteIdentifier }

            if current.count == 1 && // We found one token
                current[0].token == pushToken.deviceTokenString // It matches what we have locally
            {
                // Clear the flags and we are done
                client.pushToken = pushToken.resetFlags()
                return false
            } else {
                // There is something wrong, local token doesn't match the remotely registered

                // We should remove the local token
                client.pushToken = nil

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

public struct PushTokenPayload: Codable {

    init(pushToken: PushToken, clientIdentifier: String) {
        token = pushToken.deviceTokenString
        app = pushToken.appIdentifier
        transport = pushToken.transportType
        client = clientIdentifier
        if #available(iOS 13.3, *) {
            self.ios133 = true
        } else {
            self.ios133 = false
        }
    }
    
    public func asDictionary() -> [AnyHashable : Any]? {
        return [
            "token" : token,
            "app": app,
            "transport": transport,
            "ios133": ios133,
            "client": client
        ]
    }
    
    let token: String
    let app: String
    let transport: String
    let client: String
    let ios133: Bool
}

extension PushTokenStrategy : ZMEventConsumer {

    public func processEvents(_ events: [ZMUpdateEvent], liveEvents: Bool, prefetchResult: ZMFetchRequestBatchResult?) {
        guard liveEvents else { return }

        events.forEach{ process(updateEvent:$0) }
    }

    func process(updateEvent event: ZMUpdateEvent) {
        if event.type != .userPushRemove {
            return
        }
        // we ignore the payload and remove the locally saved copy
        let client = ZMUser.selfUser(in: self.managedObjectContext).selfClient()
        client?.pushToken = nil
    }
}

