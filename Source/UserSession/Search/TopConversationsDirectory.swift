//

import Foundation
import WireDataModel

/// Directory of various conversation lists
/// This object is expected to be used on the UI context only
@objcMembers public class TopConversationsDirectory : NSObject {

    fileprivate let uiMOC : NSManagedObjectContext
    fileprivate let syncMOC : NSManagedObjectContext
    fileprivate static let topConversationSize = 25

    /// Cached top conversations
    /// - warning: Might include deleted or blocked conversations
    fileprivate var topConversationsCache : [ZMConversation] = []

    public init(managedObjectContext: NSManagedObjectContext) {
        uiMOC = managedObjectContext
        syncMOC = managedObjectContext.zm_sync
        super.init()
        self.loadList()
    }
}

// MARK: - Top conversation
@objc extension TopConversationsDirectory {
    
//    public func refreshTopConversations() {
//        syncMOC.performGroupedBlock {
//            let conversations = self.fetchOneOnOneConversations()
//
//            // Mapping from conversation to message count in the last month
//            let countByConversation = conversations.mapToDictionary { $0.lastMonthMessageCount() }
//            let sorted = countByConversation.filter { $0.1 > 0 }.sorted {  $0.1 > $1.1 }.prefix(TopConversationsDirectory.topConversationSize)
//            let identifiers = sorted.compactMap { $0.0.objectID }
//            self.updateUIList(with: identifiers)
//        }
//    }
//
//    private func updateUIList(with identifiers: [NSManagedObjectID]) {
//        uiMOC.performGroupedBlock {
//            self.topConversationsCache = identifiers.compactMap {
//                (try? self.uiMOC.existingObject(with: $0)) as? ZMConversation
//            }
//            self.persistList()
//        }
//    }
//
//    private func fetchOneOnOneConversations() -> [ZMConversation] {
//        let request = ZMConversation.sortedFetchRequest(with: ZMConversation.predicateForActiveOneOnOneConversations)
//        return syncMOC.executeFetchRequestOrAssert(request) as! [ZMConversation]
//    }

    /// Persist list of conversations to persistent store
//    private func persistList() {
//        let valueToSave = self.topConversations.map { $0.objectID.uriRepresentation().absoluteString }
//        self.uiMOC.setPersistentStoreMetadata(array: valueToSave, key: topConversationsObjectIDKey)
//        TopConversationsDirectoryNotification().post(in: uiMOC.notificationContext)
//    }
    
    /// Top conversations
    public var topConversations : [ZMConversation] {
        return self.topConversationsCache.filter { !$0.isZombieObject && $0.connection?.status == .accepted }
    }

    /// Load list from persistent store
    fileprivate func loadList() {
        guard let ids = self.uiMOC.persistentStoreMetadata(forKey: topConversationsObjectIDKey) as? [String] else {
            return
        }
        self.topConversationsCache = ids.compactMap {
            guard let uuid = UUID(uuidString: $0) else {return nil}
            return ZMConversation(remoteID: uuid, createIfNeeded: false, in: self.uiMOC)
        }
    }
}

// MARK: – Observation
@objc public protocol TopConversationsDirectoryObserver {

    @objc func topConversationsDidChange()

}

struct TopConversationsDirectoryNotification : SelfPostingNotification {
    
    static let notificationName = NSNotification.Name(rawValue: "TopConversationsDirectoryNotification")
}

extension TopConversationsDirectory {

    @objc(addObserver:) public func add(observer: TopConversationsDirectoryObserver) -> Any {
        return NotificationInContext.addObserver(name: TopConversationsDirectoryNotification.notificationName, context: uiMOC.notificationContext) { [weak observer] note in
            observer?.topConversationsDidChange()
        }
    }
}

extension ZMConversation {

//    public static var predicateForActiveOneOnOneConversations: NSPredicate {
//        let oneOnOnePredicate = NSPredicate(format: "%K == %d", #keyPath(ZMConversation.conversationType), ZMConversationType.oneOnOne.rawValue)
//        let acceptedPredicate = NSPredicate(format: "%K == %d", #keyPath(ZMConversation.connection.status), ZMConnectionStatus.accepted.rawValue)
//        return NSCompoundPredicate(andPredicateWithSubpredicates: [oneOnOnePredicate, acceptedPredicate])
//    }
//
//    public func lastMonthMessageCount() -> Int {
//        guard let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
//        var count = 0
//        for message in lastMessages() {
//            guard let timestamp = message.serverTimestamp else { continue }
//            guard nil == message.systemMessageData else { continue }
//            guard timestamp >= oneMonthAgo else { return count }
//            count += 1
//        }
//        return count
//    }
    
}
