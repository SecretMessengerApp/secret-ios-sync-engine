//


import avs


open class AuthenticatedSessionFactory {

    let appVersion: String
    let mediaManager: MediaManagerType
    let flowManager : FlowManagerType
    var analytics: AnalyticsType?
    let application : ZMApplication
    var environment: BackendEnvironmentProvider
    let reachability: ReachabilityProvider & TearDownCapable

    public init(
        appVersion: String,
        application: ZMApplication,
        mediaManager: MediaManagerType,
        flowManager: FlowManagerType,
        environment: BackendEnvironmentProvider,
        reachability: ReachabilityProvider & TearDownCapable,
        analytics: AnalyticsType? = nil
        ) {
        self.appVersion = appVersion
        self.mediaManager = mediaManager
        self.flowManager = flowManager
        self.analytics = analytics
        self.application = application
        self.environment = environment
        self.reachability = reachability
    }

    func session(for account: Account, storeProvider: LocalStoreProviderProtocol) -> ZMUserSession? {
        let transportSession = ZMTransportSession(
            environment: environment,
            cookieStorage: environment.cookieStorage(for: account),
            reachability: reachability,
            initialAccessToken: nil,
            applicationGroupIdentifier: nil
        )
       
        if let tributaryURL = environment.tributaryURL(for: account) {
            transportSession.baseURL = tributaryURL
            transportSession.websocketURL = tributaryURL
        }
        
        return ZMUserSession(
            mediaManager: mediaManager,
            flowManager:flowManager,
            analytics: analytics,
            transportSession: transportSession,
            application: application,
            appVersion: appVersion,
            storeProvider: storeProvider
        )
    }
    
}


open class UnauthenticatedSessionFactory {

    var environment: BackendEnvironmentProvider
    let reachability: ReachabilityProvider

    init(environment: BackendEnvironmentProvider, reachability: ReachabilityProvider) {
        self.environment = environment
        self.reachability = reachability
    }

    func session(withDelegate delegate: UnauthenticatedSessionDelegate) -> UnauthenticatedSession {
        let transportSession = UnauthenticatedTransportSession(environment: environment, reachability: reachability)
        return UnauthenticatedSession(transportSession: transportSession, reachability: reachability, delegate: delegate)
    }

}
