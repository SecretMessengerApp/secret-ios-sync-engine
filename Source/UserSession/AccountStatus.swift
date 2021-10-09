//


import WireTransport
import WireDataModel

@objc public enum AccountState : UInt {
    case activated
    case newDevice // we want to show "you are using a new device"
    case deactivated // we want to show "you are using this device again"
}

public final class AccountStatus : NSObject, ZMInitialSyncCompletionObserver {

    let managedObjectContext: NSManagedObjectContext
    var authenticationToken : Any?
    var initialSyncToken: Any?
    
    public fileprivate (set) var accountState : AccountState = .activated
    
    public func initialSyncCompleted() {
        self.managedObjectContext.performGroupedBlock {
            if self.accountState == .deactivated || self.accountState == .newDevice {
                self.appendMessage(self.accountState)
                self.managedObjectContext.saveOrRollback()
            }
            self.accountState = .activated
        }
    }
    
    public func didCompleteLogin() {
        if !self.managedObjectContext.registeredOnThisDeviceBeforeConversationInitialization {
            accountState = .deactivated
        }
    }
    
    func didRegisterClient() {
        self.managedObjectContext.performGroupedBlock {
            if !self.managedObjectContext.registeredOnThisDeviceBeforeConversationInitialization {
                self.accountState = .newDevice
            }
            self.managedObjectContext.registeredOnThisDeviceBeforeConversationInitialization = false
        }
    }
    
    func appendMessage(_ state: AccountState) {
        let convRequest = NSFetchRequest<ZMConversation>(entityName:ZMConversation.entityName())
        let conversations = managedObjectContext.fetchOrAssert(request: convRequest)
        
        conversations.forEach{
            guard [.oneOnOne, .group, .hugeGroup].contains($0.conversationType) else { return }
            switch state {
            case .deactivated:
                $0.appendContinuedUsingThisDeviceMessage()
            case .newDevice:
                $0.appendStartedUsingThisDeviceMessage()
            default:
                return
            }
        }
    }
    
    @objc public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        super.init()
        
        guard managedObjectContext.zm_isSyncContext else {
            return
        }
        
        self.initialSyncToken = ZMUserSession.addInitialSyncCompletionObserver(self, context: managedObjectContext)
        self.authenticationToken = PostLoginAuthenticationNotification.addObserver(self, context: managedObjectContext)
    }
}

extension AccountStatus : PostLoginAuthenticationObserver {
    
    public func clientRegistrationDidSucceed(accountId: UUID) {
        didRegisterClient()
    }
    
}
