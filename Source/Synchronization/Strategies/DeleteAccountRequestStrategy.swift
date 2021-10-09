//


import Foundation
import WireTransport

/// Requests the account deletion
@objc public final class DeleteAccountRequestStrategy: AbstractRequestStrategy, ZMSingleRequestTranscoder {

    fileprivate static let path: String = "/self"
    public static let userDeletionInitiatedKey: String = "ZMUserDeletionInitiatedKey"
    fileprivate(set) var deleteSync: ZMSingleRequestSync! = nil
    let cookieStorage: ZMPersistentCookieStorage
    
    public init(withManagedObjectContext moc: NSManagedObjectContext, applicationStatus: ApplicationStatus, cookieStorage: ZMPersistentCookieStorage) {
        self.cookieStorage = cookieStorage
        super.init(withManagedObjectContext: moc, applicationStatus: applicationStatus)
        self.configuration = [
            .allowsRequestsDuringSync,
            .allowsRequestsWhileUnauthenticated,
            .allowsRequestsDuringEventProcessing,
            .allowsRequestsDuringNotificationStreamFetch
        ]
        self.deleteSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: self.managedObjectContext)
    }
    
    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        guard let shouldBeDeleted : NSNumber = self.managedObjectContext.persistentStoreMetadata(forKey: DeleteAccountRequestStrategy.userDeletionInitiatedKey) as? NSNumber
            , shouldBeDeleted.boolValue
        else {
            return nil
        }
        
        self.deleteSync.readyForNextRequestIfNotBusy()
        return self.deleteSync.nextRequest()
    }
    
    // MARK: - ZMSingleRequestTranscoder
    
    public func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        let request = ZMTransportRequest(path: type(of: self).path, method: .methodDELETE, payload: ([:] as ZMTransportData), shouldCompress: true)
        return request
    }

    public func didReceive(_ response: ZMTransportResponse, forSingleRequest sync: ZMSingleRequestSync) {
        if response.result == .success || response.result == .permanentError {
            self.managedObjectContext.setPersistentStoreMetadata(NSNumber(value: false), key: DeleteAccountRequestStrategy.userDeletionInitiatedKey)
            
            PostLoginAuthenticationNotification.notifyAccountDeleted(context: managedObjectContext.zm_userInterface)
        }
    }
}
