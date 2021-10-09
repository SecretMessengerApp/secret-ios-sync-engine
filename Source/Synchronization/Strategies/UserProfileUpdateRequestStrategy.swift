//

import Foundation

@objc public class UserProfileRequestStrategy : AbstractRequestStrategy {
    
    let userProfileUpdateStatus : UserProfileUpdateStatus
    
    fileprivate var phoneCodeRequestSync : ZMSingleRequestSync! = nil
    
    fileprivate var phoneUpdateSync : ZMSingleRequestSync! = nil
    
    fileprivate var phoneNumberDeleteSync : ZMSingleRequestSync! = nil
    
    fileprivate var passwordUpdateSync : ZMSingleRequestSync! = nil
    
    fileprivate var emailUpdateSync : ZMSingleRequestSync! = nil
    
    fileprivate var handleCheckSync : ZMSingleRequestSync! = nil
    
    fileprivate var handleSetSync : ZMSingleRequestSync! = nil
    
    fileprivate var handleSuggestionSearchSync : ZMSingleRequestSync! = nil
    
    @available (*, unavailable, message: "use `init(managedObjectContext:appStateDelegate:userProfileUpdateStatus)`instead")
    override init(withManagedObjectContext managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus?) {
        fatalError()
    }
    
    public init(managedObjectContext: NSManagedObjectContext,
                applicationStatus: ApplicationStatus,
                userProfileUpdateStatus: UserProfileUpdateStatus) {
        self.userProfileUpdateStatus = userProfileUpdateStatus
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        
        self.configuration = [
            .allowsRequestsWhileUnauthenticated,
            .allowsRequestsDuringSync,
            .allowsRequestsDuringEventProcessing,
            .allowsRequestsDuringNotificationStreamFetch
        ]

        self.phoneCodeRequestSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
        self.phoneUpdateSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
        self.phoneNumberDeleteSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
        self.passwordUpdateSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
        self.emailUpdateSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
        self.handleCheckSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
        self.handleSetSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
        self.handleSuggestionSearchSync = ZMSingleRequestSync(singleRequestTranscoder: self, groupQueue: managedObjectContext)
    }
    
    @objc public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        
        if self.userProfileUpdateStatus.currentlyRequestingPhoneVerificationCode {
            self.phoneCodeRequestSync.readyForNextRequestIfNotBusy()
            return self.phoneCodeRequestSync.nextRequest()
        }
        
        if self.userProfileUpdateStatus.currentlySettingPhone {
            self.phoneUpdateSync.readyForNextRequestIfNotBusy()
            return self.phoneUpdateSync.nextRequest()
        }
        
        if self.userProfileUpdateStatus.currentlySettingEmail ||
            self.userProfileUpdateStatus.currentlyChangingEmail {
            self.emailUpdateSync.readyForNextRequestIfNotBusy()
            return self.emailUpdateSync.nextRequest()
        }
        
        if self.userProfileUpdateStatus.currentlyRemovingPhoneNumber {
            self.phoneNumberDeleteSync.readyForNextRequestIfNotBusy()
            return self.phoneNumberDeleteSync.nextRequest()
        }
        
        if self.userProfileUpdateStatus.currentlySettingPassword {
            self.passwordUpdateSync.readyForNextRequestIfNotBusy()
            return self.passwordUpdateSync.nextRequest()
        }
        
        if self.userProfileUpdateStatus.currentlyCheckingHandleAvailability {
            self.handleCheckSync.readyForNextRequestIfNotBusy()
            return self.handleCheckSync.nextRequest()
        }
        
        if self.userProfileUpdateStatus.currentlySettingHandle {
            self.handleSetSync.readyForNextRequestIfNotBusy()
            return self.handleSetSync.nextRequest()
        }
        
        if self.userProfileUpdateStatus.currentlyGeneratingHandleSuggestion {
            self.handleSuggestionSearchSync.readyForNextRequestIfNotBusy()
            return self.handleSuggestionSearchSync.nextRequest()
        }
        
        return nil
    }
}

extension UserProfileRequestStrategy : ZMSingleRequestTranscoder {
    
    public func request(for sync: ZMSingleRequestSync) -> ZMTransportRequest? {
        switch sync {
            
        case self.phoneCodeRequestSync:
            let payload : NSDictionary = [
                "phone" : self.userProfileUpdateStatus.phoneNumberForWhichCodeIsRequested!
            ]
            return ZMTransportRequest(path: "/self/phone", method: .methodPUT, payload: payload)
        
        case self.phoneUpdateSync:
            let payload : NSDictionary = [
                "phone" : self.userProfileUpdateStatus.phoneNumberToSet!.phoneNumber!,
                "code" : self.userProfileUpdateStatus.phoneNumberToSet!.phoneNumberVerificationCode!,
                "dryrun" : false
            ]
            return ZMTransportRequest(path: "/activate", method: .methodPOST, payload: payload)
        
        case self.phoneNumberDeleteSync:
            return ZMTransportRequest(path: "/self/phone", method: .methodDELETE, payload: nil)

        case self.passwordUpdateSync:
            let payload : NSDictionary = [
                "new_password" : self.userProfileUpdateStatus.passwordToSet!
            ]
            return ZMTransportRequest(path: "/self/password", method: .methodPUT, payload: payload)
        
        case self.emailUpdateSync:
            let payload : NSDictionary = [
                "email" : self.userProfileUpdateStatus.emailToSet!
            ]
            return ZMTransportRequest(path: "/self/email", method: .methodPUT, payload: payload)
            
        case self.handleCheckSync:
            let handle = self.userProfileUpdateStatus.handleToCheck!
            return ZMTransportRequest(path: "/users/handles/\(handle)", method: .methodHEAD, payload: nil)
        
        case self.handleSetSync:
            let payload : NSDictionary = ["handle" : self.userProfileUpdateStatus.handleToSet!]
            return ZMTransportRequest(path: "/self/handle", method: .methodPUT, payload: payload)
            
        case self.handleSuggestionSearchSync:
            guard let handlesToCheck = self.userProfileUpdateStatus.suggestedHandlesToCheck else {
                fatal("Tried to check handles availability, but no handle was available")
            }
            let payload = [
                    "handles" :  handlesToCheck,
                    "return" : 1
                ] as NSDictionary
            return ZMTransportRequest(path: "/users/handles", method: .methodPOST, payload: payload)
        
        default:
            return nil
        }
    }
    
    public func didReceive(_ response: ZMTransportResponse, forSingleRequest sync: ZMSingleRequestSync) {
        switch sync {
            
        case self.phoneCodeRequestSync:
            if response.result == .success {
                self.userProfileUpdateStatus.didRequestPhoneVerificationCodeSuccessfully()
            } else {
                let error : Error = NSError.phoneNumberIsAlreadyRegisteredError(with: response) ??
                    NSError.invalidPhoneNumber(withReponse: response) ??
                    NSError(code: .unknownError, userInfo: nil)
                self.userProfileUpdateStatus.didFailPhoneVerificationCodeRequest(error: error)
            }
            
        case self.phoneUpdateSync:
            if response.result == .success {
                self.userProfileUpdateStatus.didChangePhoneSuccesfully()
            } else {
                let error : Error = NSError.invalidPhoneVerificationCodeError(with: response) ??
                    NSError(code: .unknownError, userInfo: nil)
                self.userProfileUpdateStatus.didFailChangingPhone(error: error)
            }
            
        case self.passwordUpdateSync:
            if response.result == .success {
                self.userProfileUpdateStatus.didUpdatePasswordSuccessfully()
            } else if response.httpStatus == 403 && response.payloadLabel() == "invalid-credentials" {
                // if the credentials are invalid, we assume that there was a previous password.
                // We decide to ignore this case because there's nothing we can do
                // and since we don't allow to change the password on the client (only to set it once), 
                // this will only be fired in some edge cases
                self.userProfileUpdateStatus.didUpdatePasswordSuccessfully()
            } else {
                self.userProfileUpdateStatus.didFailPasswordUpdate()
            }
            
        case self.emailUpdateSync:
            if response.result == .success {
                self.userProfileUpdateStatus.didUpdateEmailSuccessfully()
            } else {
                let error : Error = NSError.invalidEmail(with: response) ??
                    NSError.keyExistsError(with: response) ??
                    NSError(code: .unknownError, userInfo: nil)
                self.userProfileUpdateStatus.didFailEmailUpdate(error: error)
            }
            
        case self.phoneNumberDeleteSync:
            if response.result == .success {
                ZMUser.selfUser(in: managedObjectContext).setValue(nil, forKey: #keyPath(ZMUser.phoneNumber)) // This is a horrible hack for Swift 3.1 not seeing Obj-c private headers
                self.userProfileUpdateStatus.didRemovePhoneNumberSuccessfully()
            } else {
                let error : Error = NSError.lastUserIdentityCantBeRemoved(with: response) ??
                    NSError(code: .unknownError, userInfo: nil)
                self.userProfileUpdateStatus.didFailPhoneNumberRemoval(error: error)
            }
            
        case self.handleCheckSync:
            let handle = response.rawResponse?.url?.lastPathComponent ?? ""
            if response.result == .success {
                self.userProfileUpdateStatus.didFetchHandle(handle: handle)
            } else {
                if response.httpStatus == 404 {
                    self.userProfileUpdateStatus.didNotFindHandle(handle: handle)
                } else {
                    self.userProfileUpdateStatus.didFailRequestToFetchHandle(handle: handle)
                }
            }
            break
            
        case self.handleSetSync:
            if response.result == .success {
                self.userProfileUpdateStatus.didSetHandle()
            } else {
                if NSError.keyExistsError(with: response) != nil {
                    self.userProfileUpdateStatus.didFailToSetAlreadyExistingHandle()
                } else {
                    self.userProfileUpdateStatus.didFailToSetHandle()
                }
            }
            
        case self.handleSuggestionSearchSync:
            if response.result == .success {
                if let availableHandle = (response.payload as? [String])?.first {
                    self.userProfileUpdateStatus.didFindHandleSuggestion(handle: availableHandle)
                } else {
                    self.userProfileUpdateStatus.didNotFindAvailableHandleSuggestion()
                }
            } else {
                self.userProfileUpdateStatus.didFailToFindHandleSuggestion()
            }
            
        default:
            break
        }
    }
    
    /// Finds the handle that was searched for suggestion that is not in the given response
    private func findMissingHandleInResponse(response: ZMTransportResponse) -> String? {
        guard let usersPayload = response.payload as? [[String: AnyObject]] else {
            return nil
        }
        guard let possibleHandles = self.userProfileUpdateStatus.suggestedHandlesToCheck else {
            // this should not happen
            return nil
        }
        
        let existingHandles = Set(usersPayload.compactMap { $0["handle"] as? String })
        for handle in possibleHandles {
            if !existingHandles.contains(handle) {
                return handle
            }
        }
        return nil
    }
    
}
