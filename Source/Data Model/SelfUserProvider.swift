

import Foundation

/// A type that is able to provide an editble user.

public protocol SelfUserProvider {

    var selfUser: UserType & ZMEditableUser { get }
}
