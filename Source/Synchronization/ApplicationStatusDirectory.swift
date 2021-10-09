//

import Foundation
import CoreData
import WireRequestStrategy

@objcMembers
public final class ApplicationStatusDirectory : NSObject, ApplicationStatus {

    public let apnsConfirmationStatus : BackgroundAPNSConfirmationStatus
    public let userProfileImageUpdateStatus : UserProfileImageUpdateStatus
    public let converastionAvatarUpdateStatus : ConversationAvatarUpdateStatus
    public let userProfileUpdateStatus : UserProfileUpdateStatus
    public let clientRegistrationStatus : ZMClientRegistrationStatus
    public let clientUpdateStatus : ClientUpdateStatus
    public let pushNotificationStatus : PushNotificationStatus
    public let pushHugeNotificationStatus : PushHugeNotificationStatus
    public let accountStatus : AccountStatus
    public let proxiedRequestStatus : ProxiedRequestsStatus
    public let syncStatus : SyncStatus
    public let operationStatus : OperationStatus
    public let requestCancellation: ZMRequestCancellation
    public let analytics: AnalyticsType?
    public let teamInvitationStatus: TeamInvitationStatus
    public let assetDeletionStatus: AssetDeletionStatus
    public let callEventStatus: CallEventStatus
    
    fileprivate var callInProgressObserverToken : Any? = nil
    
    public init(withManagedObjectContext managedObjectContext : NSManagedObjectContext,
                cookieStorage : ZMPersistentCookieStorage, requestCancellation: ZMRequestCancellation, application : ZMApplication, syncStateDelegate: ZMSyncStateDelegate, analytics: AnalyticsType? = nil) {
        self.requestCancellation = requestCancellation
        self.apnsConfirmationStatus = BackgroundAPNSConfirmationStatus(application: application, managedObjectContext: managedObjectContext)
        self.operationStatus = OperationStatus()
        self.callEventStatus = CallEventStatus()
        self.analytics = analytics
        self.teamInvitationStatus = TeamInvitationStatus()
        self.operationStatus.isInBackground = application.applicationState == .background
        self.syncStatus = SyncStatus(managedObjectContext: managedObjectContext, syncStateDelegate: syncStateDelegate)
        self.userProfileUpdateStatus = UserProfileUpdateStatus(managedObjectContext: managedObjectContext)
        self.clientUpdateStatus = ClientUpdateStatus(syncManagedObjectContext: managedObjectContext)
        self.clientRegistrationStatus = ZMClientRegistrationStatus(managedObjectContext: managedObjectContext,
                                                                   cookieStorage: cookieStorage,
                                                                   registrationStatusDelegate: syncStateDelegate)
        self.accountStatus = AccountStatus(managedObjectContext: managedObjectContext)
        self.pushNotificationStatus = PushNotificationStatus(managedObjectContext: managedObjectContext)
        self.pushHugeNotificationStatus = PushHugeNotificationStatus(managedObjectContext: managedObjectContext)
        self.proxiedRequestStatus = ProxiedRequestsStatus(requestCancellation: requestCancellation)
        self.userProfileImageUpdateStatus = UserProfileImageUpdateStatus(managedObjectContext: managedObjectContext)
        self.assetDeletionStatus = AssetDeletionStatus(provider: managedObjectContext, queue: managedObjectContext)
        self.converastionAvatarUpdateStatus = ConversationAvatarUpdateStatus(managedObjectContext: managedObjectContext)
        super.init()
        
        callInProgressObserverToken = NotificationInContext.addObserver(name: CallStateObserver.CallInProgressNotification, context: managedObjectContext.notificationContext) { [weak self] (note) in
            managedObjectContext.performGroupedBlock {
                if let callInProgress = note.userInfo[CallStateObserver.CallInProgressKey] as? Bool {
                    self?.operationStatus.hasOngoingCall = callInProgress
                }
            }
        }
    }
    
    deinit {
        apnsConfirmationStatus.tearDown()
        clientRegistrationStatus.tearDown()
    }
    
    public var deliveryConfirmation: DeliveryConfirmationDelegate {
        return apnsConfirmationStatus
    }
    
    public var clientRegistrationDelegate: ClientRegistrationDelegate {
        return clientRegistrationStatus
    }
    
    public var operationState: OperationState {
        switch operationStatus.operationState {
        case .foreground:
            return .foreground
        case .background, .backgroundCall, .backgroundFetch, .backgroundTask:
            return .background
        }
    }
    
    public var synchronizationState: SynchronizationState {
        if !clientRegistrationStatus.clientIsReadyForRequests() {
            return .unauthenticated
        } else if syncStatus.isSyncing {
            return .synchronizing
        } else {
            return .eventProcessing
        }
    }
    
    public var notificationFetchStatus: BackgroundNotificationFetchStatus {
        if case .done = pushNotificationStatus.status {
            return .done
        }
        return syncStatus.isSlowSyncing ? .done : .inProgress
    }
    
    public var notificationHugeFetchStatus: BackgroundNotificationFetchStatus {
        if case .done = pushHugeNotificationStatus.status {
            return .done
        }
        return syncStatus.isSlowSyncing ? .done : .inProgress
    }
    
    public func requestSlowSync() {
        syncStatus.forceSlowSync()
    }
    
}
