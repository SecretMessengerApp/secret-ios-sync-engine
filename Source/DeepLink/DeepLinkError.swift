//

import Foundation

/**
 * Errors that can occur when requesting a user profile or conversation from a link.
 */

public enum DeepLinkRequestError: Error, Equatable {
    case invalidUserLink
    case invalidConversationLink
    case malformedLink
    case notLoggedIn
    case invalidHomeScreenLink
}
