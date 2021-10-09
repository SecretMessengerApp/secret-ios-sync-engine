//

import Foundation

private let zmLog = ZMSLog(tag: "Services")

public struct ServiceUserData: Equatable {
    let provider: UUID
    let service: UUID
    
    public init(provider: UUID, service: UUID) {
        self.provider = provider
        self.service = service
    }
}

extension ServiceUser {
    var serviceUserData: ServiceUserData? {
        guard let providerIdentifier = self.providerIdentifier,
              let serviceIdentifier = self.serviceIdentifier,
              let provider = UUID(uuidString: providerIdentifier),
              let service = UUID(uuidString: serviceIdentifier)
        else {
                return nil
        }
        
        return ServiceUserData(provider: provider,
                               service: service)
    }
}

public final class ServiceProvider: NSObject {
    public let identifier: String
    
    public let name:  String
    public let email: String
    public let url:   String
    public let providerDescription: String
    
    init?(payload: [AnyHashable: Any]) {
        guard let identifier  = payload["id"] as? String,
              let name        = payload["name"] as? String,
              let email       = payload["email"] as? String,
              let url         = payload["url"] as? String,
              let description = payload["description"] as? String
            else {
                return nil
            }
        self.identifier  = identifier
        self.name        = name
        self.email       = email
        self.url         = url
        self.providerDescription = description
        
        super.init()
    }
}

public final class ServiceDetails: NSObject {
    public let serviceIdentifier:  String
    public let providerIdentifier: String
    
    public let name: String
    public let serviceDescription: String
    public let assets: [[String: Any]]
    public let tags: [String]
    
    init?(payload: [AnyHashable: Any]) {
        guard let serviceIdentifier   = payload["id"] as? String,
              let providerIdentifier  = payload["provider"] as? String,
              let name                = payload["name"] as? String,
              let description         = payload["description"] as? String,
              let assets              = payload["assets"] as? [[String: Any]],
              let tags                = payload["tags"] as? [String]
            else {
                return nil
            }
        
        self.serviceIdentifier  = serviceIdentifier
        self.providerIdentifier = providerIdentifier
        self.name               = name
        self.serviceDescription = description
        self.assets             = assets
        self.tags               = tags

        super.init()
    }
}


public extension ServiceUserData {
    fileprivate func requestToAddService(to conversation: ZMConversation) -> ZMTransportRequest {
        guard let remoteIdentifier = conversation.remoteIdentifier
        else {
            fatal("conversation is not synced with the backend")
        }
        
        let path = "/conversations/\(remoteIdentifier.transportString())/bots"
        
        let payload: NSDictionary = ["provider": self.provider.transportString(),
                                     "service": self.service.transportString(),
                                     "locale": NSLocale.formattedLocaleIdentifier()]
        
        return ZMTransportRequest(path: path, method: .methodPOST, payload: payload as ZMTransportData)
    }
    
    fileprivate func requestToFetchProvider() -> ZMTransportRequest {
        let path = "/providers/\(provider.transportString())/"
        return ZMTransportRequest(path: path, method: .methodGET, payload: nil)
    }
    
    fileprivate func requestToFetchDetails() -> ZMTransportRequest {
        let path = "/providers/\(provider.transportString())/services/\(service.transportString())"
        return ZMTransportRequest(path: path, method: .methodGET, payload: nil)
    }
}

public extension ServiceUser {
    public func fetchProvider(in userSession: ZMUserSession, completion: @escaping (ServiceProvider?)->()) {
        guard let serviceUserData = self.serviceUserData else {
            fatal("Not a service user")
        }
        
        let request = serviceUserData.requestToFetchProvider()
        
        request.add(ZMCompletionHandler(on: userSession.managedObjectContext, block: { (response) in
            
            guard response.httpStatus == 200,
                let responseDictionary = response.payload?.asDictionary(),
                let provider = ServiceProvider(payload: responseDictionary) else {
                    zmLog.error("Wrong response for fetching a provider: \(response)")
                    completion(nil)
                    return
            }
            
            completion(provider)
        }))
        
        userSession.transportSession.enqueueOneTime(request)
    }
    
    public func fetchDetails(in userSession: ZMUserSession, completion: @escaping (ServiceDetails?)->()) {
        guard let serviceUserData = self.serviceUserData else {
            fatal("Not a service user")
        }
        
        let request = serviceUserData.requestToFetchDetails()
        
        request.add(ZMCompletionHandler(on: userSession.managedObjectContext, block: { (response) in
            
            guard response.httpStatus == 200,
                let responseDictionary = response.payload?.asDictionary(),
                let serviceDetails = ServiceDetails(payload: responseDictionary) else {
                    zmLog.error("Wrong response for fetching a service: \(response)")
                    completion(nil)
                    return
            }
            
            completion(serviceDetails)
        }))
        
        userSession.transportSession.enqueueOneTime(request)
    }
}

public enum AddBotError: Int, Error {
    case offline
    case general
    /// In case the conversation is already full, the backend is going to refuse to add the bot to the conversation.
    case tooManyParticipants
    /// The bot service is not responding to wire backend.
    case botNotResponding
    /// The bot rejected to be added to the conversation.
    case botRejected
}


public enum AddBotResult {
    case success(conversation: ZMConversation)
    case failure(error: AddBotError)
}

extension AddBotError {
    init?(response: ZMTransportResponse) {
        switch response.httpStatus {
        case 201:
            return nil
        case 403:
            self = .tooManyParticipants
        case 419:
            self = .botRejected
        case 502:
            self = .botNotResponding
        default:
            self = .general
        }
    }
}

public extension ZMConversation {
    
    func add(serviceUser: ServiceUser, in userSession: ZMUserSession, completion: ((AddBotError?)->())?) {
        guard let serviceUserData = serviceUser.serviceUserData else {
            fatal("Not a service user")
        }
        
        add(serviceUser: serviceUserData, in: userSession, completion: completion)
    }
    
    func add(serviceUser serviceUserData: ServiceUserData, in userSession: ZMUserSession, completion: ((AddBotError?)->())?) {
        guard userSession.transportSession.reachability.mayBeReachable else {
            completion?(AddBotError.offline)
            return
        }
        
        let request = serviceUserData.requestToAddService(to: self)
        
        request.add(ZMCompletionHandler(on: userSession.managedObjectContext, block: { (response) in
            
            guard response.httpStatus == 201,
                  let responseDictionary = response.payload?.asDictionary(),
                  let userAddEventPayload = responseDictionary["event"] as? ZMTransportData,
                  let event = ZMUpdateEvent(fromEventStreamPayload: userAddEventPayload, uuid: nil) else {
                    zmLog.error("Wrong response for adding a bot: \(response)")
                    completion?(AddBotError(response: response))
                    return
            }
            
            completion?(nil)
            
//            userSession.syncManagedObjectContext.performGroupedBlock {
//                // Process user added event
//                userSession.operationLoop.syncStrategy.process(updateEvents: [event], ignoreBuffer: true)
//            }
        }))
        
        userSession.transportSession.enqueueOneTime(request)
    }
}

public extension ZMUserSession {
    func startConversation(with serviceUser: ServiceUser, completion: ((AddBotResult)->())?) {
        guard let serviceUserData = serviceUser.serviceUserData else {
            fatal("Not a service user")
        }
        startConversation(with: serviceUserData, completion: completion)
    }
    
    func startConversation(with serviceUserData: ServiceUserData, completion: ((AddBotResult)->())?) {
        guard self.transportSession.reachability.mayBeReachable else {
            completion?(AddBotResult.failure(error: .offline))
            return
        }
        
        let selfUser = ZMUser.selfUser(in: self.managedObjectContext)
        
        let conversation = ZMConversation.insertNewObject(in: self.managedObjectContext)
        conversation.lastModifiedDate = Date()
        conversation.conversationType = .group
        conversation.creator = selfUser
        conversation.team = selfUser.team
        var onCreatedRemotelyToken: NSObjectProtocol? = nil
        
        _ = onCreatedRemotelyToken // remove warning
        
        onCreatedRemotelyToken = conversation.onCreatedRemotely {
            conversation.add(serviceUser: serviceUserData, in: self) { error in
                if let error = error {
                    completion?(AddBotResult.failure(error: error))
                }
                else {
                    completion?(AddBotResult.success(conversation: conversation))
                }
                onCreatedRemotelyToken = nil
            }
        }

        self.managedObjectContext.saveOrRollback()
    }
}
