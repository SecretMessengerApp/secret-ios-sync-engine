//

import Foundation

extension URL {
    enum Host {
        static let connect = "connect"
        static let login = "login"
        static let authlogin = "auth-login"
        static let invite = "invite"
        static let thirdlogin = "third-login"
        static let h5Login = "h5-login"
        static let startSSO = "start-sso"
        static let accessBackend = "access" // Used for connecting to custom backend
    }
    enum Path {
        static let success = "success"
        static let failure = "failure"
    }
}

extension URLQueryItem {
    enum Key {
        enum Connect {
            static let service = "service"
            static let provider = "provider"
        }
        enum AccessBackend {
            static let config = "config"
        }
        static let successRedirect = "success_redirect"
        static let errorRedirect = "error_redirect"
        static let cookie = "cookie"
        static let userIdentifier = "userid"
        static let errorLabel = "label"
        static let validationToken = "validation_token"
        
        static let inviteId = "id"
        
        static let authAppid = "appid"
        static let authKey = "key"
        
        static let fromid = "fromid"
        static let email = "email"
        static let userid = "userid"
    }
    
    enum Template {
        static let cookie = "$cookie"
        static let userIdentifier = "$userid"
        static let errorLabel = "$label"
    }
}

@objc public protocol URLSessionProtocol: class {
    @objc(dataTaskWithRequest:completionHandler:)
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

extension URLSession: URLSessionProtocol {}

public typealias StatusCode = Int

public enum ValidationError: Equatable {
    case invalidCode
    case invalidStatus(StatusCode)
    case unknown
    
    init?(response: HTTPURLResponse?, error: Error?) {
        switch (response?.statusCode, error) {
        case (404?, _): self = .invalidCode
        case ((400...599)?, _): self = .invalidStatus(response!.statusCode)
        case (_, .some), (.none, _): self = .unknown
        default: return nil
        }
    }
}

public protocol CompanyLoginRequesterDelegate: class {

    /**
     * The login requester asks the user to verify their identity on the given website.
     *
     * - parameter requester: The requester asking for validation.
     * - parameter url: The URL where the user should be taken to perform validation.
     */

    func companyLoginRequester(_ requester: CompanyLoginRequester, didRequestIdentityValidationAtURL url: URL)

}

/**
 * An object that validates the identity of the user and creates a session using company login.
 */

public class CompanyLoginRequester {
    
    /// The URL scheme that where the callback will be provided.
    public let callbackScheme: String

    /// The object that observes events and performs the required actions.
    public weak var delegate: CompanyLoginRequesterDelegate?

    private let defaults: UserDefaults
    private let session: URLSessionProtocol

    /// Creates a session requester that uses the specified parameters.
    public init(
        callbackScheme: String,
        defaults: UserDefaults = .shared(),
        session: URLSessionProtocol? = nil
        ) {
        self.callbackScheme = callbackScheme
        self.defaults = defaults
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    
    // MARK: - Token Validation
    
    /**
     * Validated a company login token.
     *
     * This method will verify a compy login token with the backend.
     * The requester provided by the `enqueueProvider` passed to `init` will
     * be used to perform the request.
     *
     * - parameter host: The backend to validate SSO code against.
     * - parameter token: The user login token.
     * - parameter completion: The completion closure called with the validation result.
     */
    
    public func validate(host: String, token: UUID, completion: @escaping (ValidationError?) -> Void) {
        guard let url = urlComponents(host: host, token: token).url else { fatalError("Invalid company login url.") }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let task = session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                completion(ValidationError(response: response as? HTTPURLResponse, error: error))
            }
        }
        
        task.resume()
    }

    // MARK: - Identity Request

    /**
     * Starts the company login flow for the user with the given login token.
     *
     * This method constructs the login URL, and calls the `delegate`, that will
     * handle opening the URL. Typically, this initiates the login flow, which will
     * open Safari. The `SessionManager` will handle the callback URL.
     *
     * - parameter token: The user login token, constructed from the request code.
     */

    public func requestIdentity(host: String, token: UUID) {
        let validationToken = CompanyLoginVerificationToken()
        var components = urlComponents(host: host, token: token)
        
        components.queryItems = [
            URLQueryItem(name: URLQueryItem.Key.successRedirect, value: makeSuccessCallbackString(using: validationToken)),
            URLQueryItem(name: URLQueryItem.Key.errorRedirect, value: makeFailureCallbackString(using: validationToken))
        ]

        guard let url = components.url else {
            fatalError("Invalid company login URL. This is a developer error.")
        }

        validationToken.store(in: defaults)
        delegate?.companyLoginRequester(self, didRequestIdentityValidationAtURL: url)
    }

    // MARK: - Utilities
    
    private func urlComponents(host: String, token: UUID) -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/sso/initiate-login/\(token.uuidString)"
        return components
    }

    private func makeSuccessCallbackString(using token: CompanyLoginVerificationToken) -> String {
        var components = URLComponents()
        components.scheme = callbackScheme
        components.host = URL.Host.login
        components.path = "/" + URL.Path.success

        components.queryItems = [
            URLQueryItem(name: URLQueryItem.Key.cookie, value: URLQueryItem.Template.cookie),
            URLQueryItem(name: URLQueryItem.Key.userIdentifier, value: URLQueryItem.Template.userIdentifier),
            URLQueryItem(name: URLQueryItem.Key.validationToken, value: token.uuid.transportString())
        ]

        return components.url!.absoluteString
    }

    private func makeFailureCallbackString(using token: CompanyLoginVerificationToken) -> String {
        var components = URLComponents()
        components.scheme = callbackScheme
        components.host = URL.Host.login
        components.path = "/" + URL.Path.failure

        components.queryItems = [
            URLQueryItem(name: URLQueryItem.Key.errorLabel, value: URLQueryItem.Template.errorLabel),
            URLQueryItem(name: URLQueryItem.Key.validationToken, value: token.uuid.transportString())
        ]

        return components.url!.absoluteString
    }

}

public struct PayRequest: Decodable {
    public var coin: String
    public var amount: Double
    public var trade_no: String
    public var app_id: String
    public var app_uuid: String
    public var remark: String?
    
    private enum CodingKeys:String,CodingKey{
        case coin
        case amount
        case trade_no
        case app_id
        case app_uuid
        case remark
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        coin = try container.decode(String.self, forKey: .coin)
        let strAmount = try container.decode(String.self, forKey: .amount)
        if let tmp = Double(strAmount) {
            self.amount = tmp
        } else {
            throw PayRequestError.invalidRequest
        }
        
        trade_no = try container.decode(String.self, forKey: .trade_no)
        app_id = try container.decode(String.self, forKey: .app_id)
        app_uuid = try container.decode(String.self, forKey: .app_uuid)
        remark = try? container.decode(String.self, forKey: .remark)
    }
}

extension PayRequest: Equatable {
    public static func == (lhs: PayRequest, rhs: PayRequest) -> Bool {
        return lhs.trade_no == rhs.trade_no && lhs.app_id == rhs.app_id
    }
}

public enum PayRequestError:Int, Error {
    case invalidRequest = -1
    case googleVerityNotBind = -1004 
}
