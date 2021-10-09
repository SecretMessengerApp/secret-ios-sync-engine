//

import Foundation

private let zmLog = ZMSLog(tag: "Network")

enum ConsentType: Int {
    case marketing = 2
}

enum ConsentRequestError: Error {
    case unknown
}

extension ZMUser {
    public typealias CompletionFetch = (Result<Bool>) -> Void
    
    public func fetchMarketingConsent(in userSession: ZMUserSession,
                                      completion: @escaping CompletionFetch) {
        fetchConsent(for: .marketing, in: userSession, completion: completion)
    }
    
    static func parse(consentPayload: ZMTransportData) -> [ConsentType: Bool] {
        guard let payloadDict = consentPayload.asDictionary(),
            let resultArray = payloadDict["results"] as? [[String: Any]] else {
                return [:]
        }
        
        var result: [ConsentType: Bool] = [:]
        
        resultArray.forEach {
            guard let type = $0["type"] as? Int,
                let value = $0["value"] as? Int,
                let consentType = ConsentType(rawValue: type) else {
                    return
            }
            
            let valueBool = (value == 1)
            result[consentType] = valueBool
        }
        
        return result
    }
    
    func fetchConsent(for consentType: ConsentType,
                      in userSession: ZMUserSession,
                      completion: @escaping CompletionFetch) {
        
        
        let request = ConsentRequestFactory.fetchConsentRequest()
        
        request.add(ZMCompletionHandler(on: managedObjectContext!) { response in
            
            guard 200 ... 299 ~= response.httpStatus,
                  let payload = response.payload
            else {
                let error = response.transportSessionError ?? ConsentRequestError.unknown
                zmLog.debug("Error fetching consent status: \(error)")
                completion(.failure(error))
                return
            }
            
            let parsedPayload = ZMUser.parse(consentPayload: payload)
            let status: Bool = parsedPayload[consentType] ?? false
            completion(.success(status))
        })
        
        userSession.transportSession.enqueueOneTime(request)
    }
    
    public typealias CompletionSet   = (VoidResult) -> Void
    public func setMarketingConsent(to value: Bool,
                                    in userSession: ZMUserSession,
                                    completion: @escaping CompletionSet) {
        setConsent(to: value, for: .marketing, in: userSession, completion: completion)
    }
    
    func setConsent(to value: Bool,
                    for consentType: ConsentType,
                    in userSession: ZMUserSession,
                    completion: @escaping CompletionSet) {
        let request = ConsentRequestFactory.setConsentRequest(for: consentType, value: value)
        
        request.add(ZMCompletionHandler(on: managedObjectContext!) { response in
            
            guard 200 ... 299 ~= response.httpStatus
                else {
                    let error = response.transportSessionError ?? ConsentRequestError.unknown
                    zmLog.debug("Error setting consent status: \(error)")
                    completion(.failure(error))
                    return
            }
            
            completion(.success)
        })
        
        userSession.transportSession.enqueueOneTime(request)
    }
}

struct ConsentRequestFactory {
    static let consentPath = "/self/consent"
    
    static func fetchConsentRequest() -> ZMTransportRequest {
        return .init(getFromPath: consentPath)
    }
    
    static var sourceString: String {
        return "iOS " + Bundle.main.version
    }
    
    static func setConsentRequest(for consentType: ConsentType, value: Bool) -> ZMTransportRequest {
        let payload: [String: Any] = [
            "type": consentType.rawValue,
            "value": value ? 1:0,
            "source": sourceString
        ]
        return .init(path: consentPath,
                     method: .methodPUT,
                     payload: payload as ZMTransportData)
    }
}
