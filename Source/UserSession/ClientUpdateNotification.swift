//

import WireDataModel


@objc public enum ZMClientUpdateNotificationType: Int {
    case fetchCompleted
    case fetchFailed
    case deletionCompleted
    case deletionFailed
}

@objc public class ZMClientUpdateNotification: NSObject {
    
    private static let name = Notification.Name(rawValue: "ZMClientUpdateNotification")
    
    private static let clientObjectIDsKey = "clientObjectIDs"
    private static let typeKey = "notificationType"
    private static let errorKey = "error"
    
    @objc public static func addOserver(context: NSManagedObjectContext, block: @escaping (ZMClientUpdateNotificationType, [NSManagedObjectID], NSError?) -> ()) -> Any {
        return NotificationInContext.addObserver(name: self.name,
                                                 context: context.notificationContext)
        { note in
            guard let type = note.userInfo[self.typeKey] as? ZMClientUpdateNotificationType else { return }
            let clientObjectIDs = (note.userInfo[self.clientObjectIDsKey] as? [NSManagedObjectID]) ?? []
            let error = note.userInfo[self.errorKey] as? NSError
            block(type, clientObjectIDs, error)
        }
    }
    
    static func notify(type: ZMClientUpdateNotificationType, context: NSManagedObjectContext, clients: [UserClient] = [], error: NSError? = nil) {
        NotificationInContext(name: self.name, context: context.notificationContext, userInfo: [
            errorKey: error as Any,
            clientObjectIDsKey: clients.objectIDs,
            typeKey: type
        ]).post()
    }
    
    @objc
    public static func notifyFetchingClientsCompleted(userClients: [UserClient], context: NSManagedObjectContext) {
        self.notify(type: .fetchCompleted, context: context, clients: userClients)
    }
    
    @objc
    public static func notifyFetchingClientsDidFail(error: NSError, context: NSManagedObjectContext) {
        self.notify(type: .fetchFailed, context: context, error: error)
    }
    
    @objc
    public static func notifyDeletionCompleted(remainingClients: [UserClient], context: NSManagedObjectContext) {
        self.notify(type: .deletionCompleted, context: context, clients: remainingClients)
    }
    
    @objc
    public static func notifyDeletionFailed(error: NSError, context: NSManagedObjectContext) {
        self.notify(type: .deletionFailed, context: context, error: error)
    }
}

extension Array where Element: NSManagedObject {
    
    var objectIDs: [NSManagedObjectID] {
        return self.compactMap { obj in
            guard !obj.objectID.isTemporaryID else { return nil }
            return obj.objectID
        }
    }
}
