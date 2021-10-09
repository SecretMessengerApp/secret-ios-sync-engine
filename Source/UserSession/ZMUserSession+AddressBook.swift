//

import Foundation

private let log = ZMSLog(tag: "AddressBook")

// MARK: - Upload observer
let failedToAccessAddressBookNotificationName = Notification.Name(rawValue: "ZMUserSessionFailedToAccessAddressBook")

@objc public protocol AddressBookUploadObserver {
    
    /// This method will get called when the app tries to upload the address book, but does not have access to it.
    func failedToAccessAddressBook()
}

extension ZMUserSession {
    
    /// Adds and observer for address book upload. Returns the token that need to be used
    /// to unregister the observer
    public static func addAddressBookUploadObserver(_ observer: AddressBookUploadObserver, context: NSManagedObjectContext) -> Any {
        return NotificationInContext.addObserver(
            name: failedToAccessAddressBookNotificationName,
            context: context.notificationContext,
            using: { [weak observer] _ in observer?.failedToAccessAddressBook() })
    }
}

// MARK: - Address book upload
extension ZMUserSession {

    /// Asynchronously uploads the next chunk of the address book unless the user is in a team
    public func uploadAddressBookIfAllowed() {
        if ZMUser.selfUser(inUserSession: self).hasTeam {
            log.error("Uploading contacts for an account with team is a forbidden operation")
        } else {
            uploadAddressBook()
        }
    }

    /// Asynchronously uploads the next chunk of the address book
    private func uploadAddressBook() {
        AddressBook.markAddressBookAsNeedingToBeUploaded(self.managedObjectContext)
        self.managedObjectContext.forceSaveOrRollback()
    }

}
