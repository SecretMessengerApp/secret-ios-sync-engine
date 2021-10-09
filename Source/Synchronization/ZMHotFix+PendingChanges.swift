//


import Foundation


extension ZMUserSession {

    /// This flag is an abstraction for the UI to use in case a HotFix relies on
    /// changes to be made which should not be checked from the UI directly.
    /// The is caused by the fact that a HotFix gets applied in the EventProcessingState,
    /// (see `ZMEventProcessingState.h` in `didEnterState`), after which the initial sync 
    /// will be completed. In case a HotFix relies on a network request being made (e.g. when refetching a user),
    /// the notification for the initial sync completion might be fired before that request completed.
    /// In order to ensure all HotFix related changes have been made (including requests) the UI
    /// should use this flag instead to check if there are pending changes.
    @objc public var isPendingHotFixChanges: Bool {

        // Related to HotFix 62.3.1 (see `refetchConnectedUsers`)
        // we need to refetch the user to ensure we have its username locally in case it was set on a secondary device.
        return ZMUser.selfUser(in: managedObjectContext).needsToBeUpdatedFromBackend
    }

}
