

import Foundation

extension ZMUserSession: SelfUserProvider {

    public var selfUser: UserType & ZMEditableUser {
        return ZMUser.selfUser(in: managedObjectContext)
    }
}
