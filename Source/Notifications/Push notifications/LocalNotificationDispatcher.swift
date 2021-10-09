//

import Foundation
import UserNotifications

/// Creates and cancels local notifications
@objcMembers public class LocalNotificationDispatcher: NSObject {

    public static let ZMShouldHideNotificationContentKey = "ZMShouldHideNotificationContentKey"

    let eventNotifications: ZMLocalNotificationSet
    let messageNotifications: ZMLocalNotificationSet
    let callingNotifications: ZMLocalNotificationSet
    let failedMessageNotifications: ZMLocalNotificationSet

    var notificationCenter: UserNotificationCenter = UNUserNotificationCenter.current()

    let syncMOC: NSManagedObjectContext
    fileprivate(set) var isTornDown: Bool
    fileprivate var observers: [Any] = []

    var localNotificationBuffer = [ZMLocalNotification]()

    @objc(initWithManagedObjectContext:)
    public init(in managedObjectContext: NSManagedObjectContext) {
        self.syncMOC = managedObjectContext
        self.eventNotifications = ZMLocalNotificationSet(archivingKey: "ZMLocalNotificationDispatcherEventNotificationsKey", keyValueStore: managedObjectContext)
        self.failedMessageNotifications = ZMLocalNotificationSet(archivingKey: "ZMLocalNotificationDispatcherFailedNotificationsKey", keyValueStore: managedObjectContext)
        self.callingNotifications = ZMLocalNotificationSet(archivingKey: "ZMLocalNotificationDispatcherCallingNotificationsKey", keyValueStore: managedObjectContext)
        self.messageNotifications = ZMLocalNotificationSet(archivingKey: "ZMLocalNotificationDispatcherMessageNotificationsKey", keyValueStore: managedObjectContext)
        self.isTornDown = false
        super.init()
        observers.append(
            NotificationInContext.addObserver(name: ZMConversation.lastReadDidChangeNotificationName,
                                              context: managedObjectContext.notificationContext,
                                              using: { [weak self] in self?.cancelNotificationForLastReadChanged(notification: $0)})
        )
    }



    deinit {
        precondition(self.isTornDown)
    }

    func scheduleLocalNotification(_ note: ZMLocalNotification) {
        Logging.push.safePublic("Scheduling local notification with id=\(note.id)")
        
        notificationCenter.add(note.request, withCompletionHandler: nil)
    }

    /// Determines if the notification content should be hidden as reflected in the store
    /// metatdata for the given managed object context.
    ///
    static func shouldHideNotificationContent(moc: NSManagedObjectContext?) -> Bool {
        let value = moc?.persistentStoreMetadata(forKey: ZMShouldHideNotificationContentKey) as? NSNumber
        return value?.boolValue ?? false
    }
}

extension LocalNotificationDispatcher: ZMEventConsumer {

    public func processEvents(_ events: [ZMUpdateEvent], liveEvents: Bool, prefetchResult: ZMFetchRequestBatchResult?) {
        let eventsToForward = events.filter { $0.source.isOne(of: .pushNotification, .webSocket) } 
        self.didReceive(events: eventsToForward, conversationMap: prefetchResult?.conversationsByRemoteIdentifier ?? [:])
    }

    func didReceive(events: [ZMUpdateEvent], conversationMap: [UUID: ZMConversation]) {
        events.forEach { event in

            var conversation: ZMConversation?
            if let conversationID = event.conversationUUID() {
                // Fetch the conversation here to avoid refetching every time we try to create a notification
                conversation = conversationMap[conversationID] ?? ZMConversation.fetch(withRemoteIdentifier: conversationID, in: self.syncMOC)
            }

            // if it's an "unlike" reaction event, cancel the previous "like" notification for this message
            if let receivedMessage = ZMGenericMessage(from: event), receivedMessage.hasReaction(), receivedMessage.reaction.emoji.isEmpty {
                UUID(uuidString: receivedMessage.reaction.messageId).apply(eventNotifications.cancelCurrentNotifications(messageNonce:))
            }
            
            let note = ZMLocalNotification(event: event, conversation: conversation, managedObjectContext: self.syncMOC)
            note.apply(eventNotifications.addObject)
            note.apply(scheduleLocalNotification)
        }
    }
}

extension LocalNotificationDispatcher: TearDownCapable {
    public func tearDown() {
        self.isTornDown = true
        self.observers = []
        syncMOC.performGroupedBlock { [weak self] in
            self?.cancelAllNotifications()
        }
    }
}

// MARK: - Availability behaviour change

extension LocalNotificationDispatcher {
    
    public func notifyAvailabilityBehaviourChangedIfNeeded() {
        let selfUser = ZMUser.selfUser(in: syncMOC)
        var notify = selfUser.needsToNotifyAvailabilityBehaviourChange
        
        guard notify.contains(.notification) else { return }
        
        let note = ZMLocalNotification(availability: selfUser.availability, managedObjectContext: syncMOC)
        note.apply(scheduleLocalNotification)
        notify.remove(.notification)
        selfUser.needsToNotifyAvailabilityBehaviourChange = notify
        syncMOC.enqueueDelayedSave()
    }
    
}

// MARK: - Failed messages

extension LocalNotificationDispatcher {

    /// Informs the user that the message failed to send
    public func didFailToSend(_ message: ZMMessage) {
        let objectID = message.objectID
        self.syncMOC.performGroupedBlock {
            [unowned self] in
            if let syncMessage = (try? self.syncMOC.existingObject(with: objectID)) as? ZMMessage {
                if syncMessage.visibleInConversation == nil || syncMessage.conversation?.conversationType == .self {
                    return
                }
                let note = ZMLocalNotification(expiredMessage: syncMessage)
                note.apply(self.scheduleLocalNotification)
                note.apply(self.failedMessageNotifications.addObject)
            }
        }
    }

    /// Informs the user that a message in a conversation failed to send
    public func didFailToSendMessage(in conversation: ZMConversation) {
        let objectID = conversation.objectID
        self.syncMOC.performGroupedBlock {
            [unowned self] in
            if let syncConversation = (try? self.syncMOC.existingObject(with: objectID)) as? ZMConversation {
                let note = ZMLocalNotification(expiredMessageIn: syncConversation)
                note.apply(self.scheduleLocalNotification)
                note.apply(self.failedMessageNotifications.addObject)
            }
        }
    }
}

// MARK: - Canceling notifications

extension LocalNotificationDispatcher {

    private var allNotificationSets: [ZMLocalNotificationSet] {
        return [self.eventNotifications,
                self.failedMessageNotifications,
                self.messageNotifications,
                self.callingNotifications]
    }

    /// Can be used for cancelling all conversations if need
    public func cancelAllNotifications() {
        self.allNotificationSets.forEach { $0.cancelAllNotifications() }
    }

    /// Cancels all notifications for a specific conversation
    /// - note: Notifications for a specific conversation are otherwise deleted automatically when the message window changes and
    /// ZMConversationDidChangeVisibleWindowNotification is called
    public func cancelNotification(for conversation: ZMConversation) {
        self.allNotificationSets.forEach { $0.cancelNotifications(conversation) }
    }

    /// Cancels all notification in the conversation that is speficied as object of the notification
    func cancelNotificationForLastReadChanged(notification: NotificationInContext) {
        guard let conversation = notification.object as? ZMConversation else { return }
        let conversationID = conversation.objectID
        self.syncMOC.performGroupedBlock {
            if let syncConversation = (try? self.syncMOC.existingObject(with: conversationID)) as? ZMConversation {
                self.cancelNotification(for: syncConversation)
            }
        }
    }
}
