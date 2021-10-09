//

import Foundation

extension Team {
    
    /**
     Invite someone to your team via email
     
     - parameters:
         - email: Email address to which invitation will be sent
         - userSession: Session which the invitation should be sent from
         - completion: Handler which will be called on the main thread when the invitation has been sent
     */
    public func invite(email : String, in userSession : ZMUserSession, completion: @escaping InviteCompletionHandler) {
        userSession.syncManagedObjectContext.performGroupedBlock {
            userSession.applicationStatusDirectory.teamInvitationStatus.invite(email, completionHandler: { [weak userSession] result in
                userSession?.managedObjectContext.performGroupedBlock {
                    completion(result)
                }
            })
        }
    }
    
}
