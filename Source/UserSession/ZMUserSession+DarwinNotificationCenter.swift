//

import Foundation
import WireUtilities

@objc extension ZMUserSession {
    /// Listens and reacts to hints from the share extension that the user
    /// session should try to merge changes to its managed object contexts.
    /// This ensures that the UI is up to date when the share extension has
    /// been invoked while the app is active.
    @objc public func observeChangesOnShareExtension() {
        DarwinNotificationCenter.shared.observe(notification: .shareExtDidSaveNote) { [weak self] () in
            self?.mergeChangesFromStoredSaveNotificationsIfNeeded()
        }
    }
}
