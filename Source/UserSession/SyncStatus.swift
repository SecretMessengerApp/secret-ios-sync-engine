//

@objc public enum SyncPhase : Int, CustomStringConvertible, CaseIterable {
    case fetchingLastUpdateEventID
    case fetchingConnections
    case fetchingConversations
    case fetchingUsers
    case fetchingSelfUser
    case fetchingMissedEvents
    case fetchingHugeMissedEvents
    case done
    
    var isLastSlowSyncPhase : Bool {
        return self == .fetchingUsers
    }
    
    var isSyncing : Bool {
        return self != .done
    }

    var nextPhase: SyncPhase {
        return SyncPhase(rawValue: rawValue + 1) ?? .done
    }
    
    public var description: String {
        switch self {
        case .fetchingLastUpdateEventID:
            return "fetchingLastUpdateEventID"
        case .fetchingConnections:
            return "fetchingConnections"
        case .fetchingConversations:
            return "fetchingConversations"
        case .fetchingUsers:
            return "fetchingUsers"
        case .fetchingSelfUser:
            return "fetchingSelfUser"
        case .fetchingMissedEvents:
            return "fetchingMissedEvents"
        case .fetchingHugeMissedEvents:
            return "fetchingHugeMissedEvents"
        case .done:
            return "done"
        }
    }
}

private let zmLog = ZMSLog(tag: "SyncStatus")


extension Notification.Name {

    public static let ForceSlowSync = Notification.Name("restartSlowSyncNotificationName")
    
    public static let TrackSyncPhase = Notification.Name("trackSyncPhase")
}


@objcMembers public class SyncStatus : NSObject {

    public internal (set) var currentSyncPhase : SyncPhase = .done {
        didSet {
            if currentSyncPhase != oldValue {
                print("did change sync phase: \(currentSyncPhase)")
                notifySyncPhaseDidStart()
                NotificationCenter.default.post(name: .TrackSyncPhase, object: nil, userInfo: ["trackSyncPhase" : currentSyncPhase])
            }
        }
    }

    fileprivate var lastUpdateEventID : UUID?
    fileprivate var lastHugeUpdateEventID : UUID?
    fileprivate unowned var managedObjectContext: NSManagedObjectContext
    fileprivate unowned var syncStateDelegate: ZMSyncStateDelegate
    fileprivate var forceSlowSyncToken : Any?
    
    public internal (set) var isInBackground : Bool = false
    public internal (set) var needsToRestartQuickSync : Bool = false
    public internal (set) var pushChannelEstablishedDate : Date?
    
    fileprivate var pushChannelIsOpen : Bool {
        return pushChannelEstablishedDate != nil
    }
    
    public var isSlowSyncing : Bool {
        return !currentSyncPhase.isOne(of: [.fetchingMissedEvents, .fetchingHugeMissedEvents, .done])
    }
    
    public var isSyncing : Bool {
        return currentSyncPhase.isSyncing
    }
    
    public init(managedObjectContext: NSManagedObjectContext, syncStateDelegate: ZMSyncStateDelegate) {
        self.managedObjectContext = managedObjectContext
        self.syncStateDelegate = syncStateDelegate
        super.init()
        
        currentSyncPhase = hasPersistedLastEventID ? .fetchingMissedEvents : .fetchingLastUpdateEventID
        notifySyncPhaseDidStart()
        
        self.forceSlowSyncToken = NotificationInContext.addObserver(name: .ForceSlowSync, context: managedObjectContext.notificationContext) { [weak self] (note) in
            self?.forceSlowSync()
        }
    }
    
    fileprivate func notifySyncPhaseDidStart() {
        switch currentSyncPhase {
        case .fetchingMissedEvents:
            syncStateDelegate.didStartQuickSync()
        case .fetchingLastUpdateEventID:
            syncStateDelegate.didStartSlowSync()
        default:
            break
        }
    }
    
    public func forceSlowSync() {
        // Refetch user settings.
        ZMUser.selfUser(in: managedObjectContext).needsPropertiesUpdate = true
        // Set the status.
        currentSyncPhase = SyncPhase.fetchingLastUpdateEventID.nextPhase
        syncStateDelegate.didStartSlowSync()
    }
    
}

// MARK: Slow Sync
extension SyncStatus {
    
    public func finishCurrentSyncPhase(phase : SyncPhase) {
        precondition(phase == currentSyncPhase, "Finished syncPhase does not match currentPhase")
        
        zmLog.debug("finished sync phase: \(phase)")
        
        if phase.isLastSlowSyncPhase {
            persistLastUpdateEventID()
            syncStateDelegate.didFinishSlowSync()
        }
        
        currentSyncPhase = phase.nextPhase
        
        if currentSyncPhase == .done {
            if needsToRestartQuickSync && pushChannelIsOpen {
                // If the push channel closed while fetching notifications
                // We need to restart fetching the notification stream since we might be missing notifications
                currentSyncPhase = .fetchingMissedEvents
                needsToRestartQuickSync = false
                zmLog.debug("restarting quick sync since push channel was closed")
                return
            }
            
            zmLog.debug("sync complete")
            syncStateDelegate.didFinishQuickSync()
        }
        RequestAvailableNotification.notifyNewRequestsAvailable(self)
    }
    
    public func failCurrentSyncPhase(phase : SyncPhase) {
        precondition(phase == currentSyncPhase, "Failed syncPhase does not match currentPhase")
        
        zmLog.debug("failed sync phase: \(phase)")
        
        if currentSyncPhase == .fetchingMissedEvents {
            managedObjectContext.zm_lastNotificationID = nil
            currentSyncPhase = .fetchingLastUpdateEventID
            needsToRestartQuickSync = false
        }
    }
    
    var hasPersistedLastEventID : Bool {
        return managedObjectContext.zm_lastNotificationID != nil
    }
    
    public func updateLastUpdateEventID(eventID : UUID) {
        zmLog.debug("update last eventID: \(eventID)")
        lastUpdateEventID = eventID
    }
    
    public func updateLastHugeUpdateEventID(eventID : UUID) {
        zmLog.debug("update last huge eventID: \(eventID)")
        lastHugeUpdateEventID = eventID
    }
    
    public func persistLastUpdateEventID() {
        guard let lastUpdateEventID = lastUpdateEventID else { return }
        guard let lastHugeUpdateEventID = lastHugeUpdateEventID else { return }
        zmLog.debug("persist last eventID: \(lastUpdateEventID)")
        zmLog.debug("persist last huge eventID: \(lastHugeUpdateEventID)")
        managedObjectContext.zm_lastNotificationID = lastUpdateEventID
        managedObjectContext.zm_lastHugeNotificationID = lastHugeUpdateEventID
    }
}

// MARK: Quick Sync
extension SyncStatus {
    
    public func pushChannelDidClose() {
        pushChannelEstablishedDate = nil
        
        if !currentSyncPhase.isSyncing {
            // As soon as the pushChannel closes we should notify the UI that we are syncing (if we are not already syncing)
            self.syncStateDelegate.didStartQuickSync()
        }
    }
    
    public func pushChannelDidOpen() {
        pushChannelEstablishedDate = Date()
        
        if currentSyncPhase == .fetchingMissedEvents {
            // If the push channel closed while we are fetching the notifications, we might be missing notifications that
            // were sent between the server response and the channel re-opening We therefore need to mark the quick sync to be re-started
            needsToRestartQuickSync = true
        }
        
        if !currentSyncPhase.isSyncing {
            // When the push channel opens we need to start syncing (if we are not already syncing)
            self.currentSyncPhase = .fetchingMissedEvents
        }
    }
    
}

