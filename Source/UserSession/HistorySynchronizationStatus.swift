// 


import Foundation

@objc public protocol HistorySynchronizationStatus : NSObjectProtocol
{
    /// Should be called when the sync is completed
    func didCompleteSync()
    
    /// Should be called when the sync is started
    func didStartSync()
    
    /// Whether the history can now be downloaded
    var shouldDownloadFullHistory : Bool { get }
}

@objc public final class ForegroundOnlyHistorySynchronizationStatus : NSObject, HistorySynchronizationStatus
{
    fileprivate var isSyncing = false
    fileprivate var isInBackground = false
    fileprivate let application : ZMApplication
    
    /// Managed object context used to execute on the right thread
    fileprivate var moc : NSManagedObjectContext
    
    public init(managedObjectContext: NSManagedObjectContext,
                application: ZMApplication) {
        self.moc = managedObjectContext
        self.isSyncing = true
        self.isInBackground = false
        self.application = application
        super.init()
        application.registerObserverForDidBecomeActive(self, selector: #selector(didBecomeActive(_:)))
        application.registerObserverForWillResignActive(self, selector: #selector(willResignActive(_:)))
    }
    
    deinit {
        self.application.unregisterObserverForStateChange(self)
    }
    
    @objc public func didBecomeActive(_ note: Notification) {
        self.moc.performGroupedBlock { () -> Void in
            self.isInBackground = false
        }
    }

    @objc public func willResignActive(_ note: Notification) {
        self.moc.performGroupedBlock { () -> Void in
            self.isInBackground = true
        }
    }

    
    /// Should be called when the initial synchronization is done
    public func didCompleteSync() {
        self.isSyncing = false
    }
    
    /// Should be called when some synchronization (slow or quick) is started
    public func didStartSync() {
        self.isSyncing = true
    }
    
    /// Returns whether history should be downloaded now
    public var shouldDownloadFullHistory : Bool {
        return !self.isSyncing && !self.isInBackground;
    }
}

