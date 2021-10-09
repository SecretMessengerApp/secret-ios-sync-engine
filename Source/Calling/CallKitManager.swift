

import Foundation
import CallKit
import Intents
import avs

private let identifierSeparator : Character = "+"

// Represents a call managed by CallKit

private struct CallKitCall {
    let conversation : ZMConversation
    let observer : CallObserver
    
    init(conversation : ZMConversation) {
        self.conversation = conversation
        self.observer = CallObserver(conversation: conversation)
    }
}

private class WaitingConvInfoCall: ZMTimerClient {
    
    enum State {
        case incoming
        case answering
        case finallyWaited 
        case waitedTimeout
    }
    
    let cid : UUID
    var state: State
    var onWaitingTimeout : (() -> Void)?
    var onWaitingSuccess : (() -> Void)?
    var timer: ZMTimer?
    
    init(cid : UUID) {
        self.cid = cid
        self.state = .incoming
    }
    
    func updateState(_ state: State) {
        self.state = state
        switch state {
        case .incoming:
            break;
        case .answering:
            timer = ZMTimer.init(target: self)
            timer?.fire(at: Date.init(timeIntervalSinceNow: 30))
        case .finallyWaited:
            onWaitingSuccess?()
            self.timer?.cancel()
            self.timer = nil
        case .waitedTimeout:
            self.timer = nil
            onWaitingTimeout?()
        }
    }
    
    func timerDidFire(_ timer: ZMTimer!) {
        self.updateState(.waitedTimeout)
    }
}

/// Represents the location of a call uniquely across accounts

struct CallHandle: Hashable {
    let accountId: UUID
    let conversationId: UUID
    
    init?(customIdentifier value: String) {
        let identifiers = value.split(separator: identifierSeparator).compactMap({ UUID(uuidString: String($0)) })
        
        guard identifiers.count == 2 else { return nil }
        
        self.accountId = identifiers[0]
        self.conversationId = identifiers[1]
    }
}

protocol CallKitManagerDelegate: class {
    
    /// Look a conversation where a call has or will take place
    
    func lookupConversation(by handle: CallHandle, completionHandler: @escaping (Result<ZMConversation>) -> Void)
    
    /// End all active calls in all user sessions
    
    func endAllCalls()
    
}

@objc
public class CallKitManager: NSObject {
    
    fileprivate let provider: CXProvider
    fileprivate let callController: CXCallController
    fileprivate weak var delegate: CallKitManagerDelegate?
    fileprivate weak var mediaManager: MediaManagerType?
    fileprivate var callStateObserverToken: Any?
    fileprivate var missedCallObserverToken: Any?
    fileprivate var connectedCallConversation: ZMConversation?
    fileprivate var calls: [UUID : CallKitCall]

    fileprivate var stashIncommingCallConvs: [UUID: WaitingConvInfoCall]
    
    convenience init(delegate: CallKitManagerDelegate, mediaManager: MediaManagerType?) {
        self.init(provider: CXProvider(configuration: CallKitManager.providerConfiguration),
                  callController: CXCallController(queue: DispatchQueue.main),
                  delegate: delegate,
                  mediaManager: mediaManager)
    }
    
    init(provider: CXProvider,
         callController: CXCallController,
         delegate: CallKitManagerDelegate,
         mediaManager: MediaManagerType?) {
        
        self.provider = provider
        self.callController = callController
        self.delegate = delegate
        self.mediaManager = mediaManager
        self.calls = [:]
        self.stashIncommingCallConvs = [:]
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
                
        callStateObserverToken = WireCallCenterV3.addGlobalCallStateObserver(observer: self)
        missedCallObserverToken = WireCallCenterV3.addGlobalMissedCallObserver(observer: self)
    }
    
    deinit {
        provider.invalidate()
    }
    
    public func updateConfiguration() {
        provider.configuration = CallKitManager.providerConfiguration
    }
    
    internal static var providerConfiguration : CXProviderConfiguration {
        
        let localizedName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Secret"
        let configuration = CXProviderConfiguration(localizedName: localizedName)

        configuration.supportsVideo = true
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.ringtoneSound = NotificationSound.call.name
        
        if let image = UIImage(named: "callKitLogo") {
            configuration.iconTemplateImageData = image.pngData()
        }
        
        return configuration
    }
    
    fileprivate func log(_ message: String, file: String = #file, line: Int = #line) {
        let messageWithLineNumber = String(format: "%@:%ld: %@", URL(fileURLWithPath: file).lastPathComponent, line, message)
        SessionManager.logAVS(message: messageWithLineNumber)
    }

    fileprivate func actionsToEndAllOngoingCalls(exceptIn conversation: ZMConversation) -> [CXAction] {
        return calls
            .lazy
            .filter { $0.value.conversation != conversation }
            .map { CXEndCallAction(call: $0.key) }
    }
    
    internal func callUUID(for conversation: ZMConversation) -> UUID? {
        return calls.first(where: { $0.value.conversation == conversation })?.key
    }

}

extension CallKitManager {
    
    func findConversationAssociated(with contacts: [INPerson], completion: @escaping (ZMConversation) -> Void) {
        
        guard contacts.count == 1,
              let contact = contacts.first,
              let customIdentifier = contact.personHandle?.value,
              let callHandle = CallHandle(customIdentifier: customIdentifier)
        else {
            return
        }
        
        delegate?.lookupConversation(by: callHandle, completionHandler: { (result) in
            guard case .success(let conversation) = result else { return }
            completion(conversation)
        })
    }
    
    public func continueUserActivity(_ userActivity : NSUserActivity) -> Bool {
        guard let interaction = userActivity.interaction
        else { return false }
        
        let intent = interaction.intent
        var contacts : [INPerson]? = nil
        var video = false
        
        if let audioCallIntent = intent as? INStartAudioCallIntent {
            contacts = audioCallIntent.contacts
            video = false
        }
        else if let videoCallIntent = intent as? INStartVideoCallIntent {
            contacts = videoCallIntent.contacts
            video = true
        }
        
        if let contacts = contacts {
            findConversationAssociated(with: contacts) { [weak self] (conversation) in
                self?.requestStartCall(in: conversation, video: video)
            }
            
            return true
        }
        
        return false
    }
}

extension CallKitManager {
    
    func requestMuteCall(in conversation: ZMConversation, muted:  Bool) {
        guard let existingCallUUID = callUUID(for: conversation) else { return }
        
        let action = CXSetMutedCallAction(call: existingCallUUID, muted: muted)
        
        callController.request(CXTransaction(action: action)) { [weak self] (error) in
            if let error = error {
                self?.log("Cannot update call to muted = \(muted): \(error)")
            }
        }
    }
    
    func requestJoinCall(in conversation: ZMConversation, video: Bool) {
        
        let existingCallUUID = callUUID(for: conversation)
        let existingCall = callController.callObserver.calls.first(where: { $0.uuid == existingCallUUID })
        
        if let call = existingCall, !call.isOutgoing {
            requestAnswerCall(in: conversation, video: video)
        } else {
            requestStartCall(in: conversation, video: video)
        }
    }
    
    func requestStartCall(in conversation: ZMConversation, video: Bool) {
        guard
            let managedObjectContext = conversation.managedObjectContext,
            let handle = conversation.callKitHandle
        else {
            self.log("Ignore request to start call since remoteIdentifier or handle is nil")
            return
        }
        
        let callUUID = UUID()
        calls[callUUID] = CallKitCall(conversation: conversation)
        
        let action = CXStartCallAction(call: callUUID, handle: handle)
        action.isVideo = video
        action.contactIdentifier = conversation.localizedCallerName(with: ZMUser.selfUser(in: managedObjectContext))

        let endCallActions = actionsToEndAllOngoingCalls(exceptIn: conversation)
        let transaction = CXTransaction(actions: endCallActions + [action])
        
        log("request CXStartCallAction")
        
        callController.request(transaction) { [weak self] (error) in
            if let error = error as? CXErrorCodeRequestTransactionError, error.code == .callUUIDAlreadyExists {
                self?.requestAnswerCall(in: conversation, video: video)
            } else if let error = error {
                self?.log("Cannot start call: \(error)")
            }
        }
        
    }
    
    func requestAnswerCall(in conversation: ZMConversation, video: Bool) {
        guard let callUUID = callUUID(for: conversation) else { return }
        
        let action = CXAnswerCallAction(call: callUUID)
        let endPreviousActions = actionsToEndAllOngoingCalls(exceptIn: conversation)
        let transaction = CXTransaction(actions: endPreviousActions + [action])
        
        log("request CXAnswerCallAction")
        
        callController.request(transaction) { [weak self] (error) in
            if let error = error {
                self?.log("Cannot answer call: \(error)")
            }
        }
    }
    
    func requestEndCall(in conversation: ZMConversation, completion: (()->())? = nil) {
        guard let callUUID = callUUID(for: conversation) else { return }
        
        let action = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: action)
        
        log("request CXEndCallAction")
        
        callController.request(transaction) { [weak self] (error) in
            if let error = error {
                self?.log("Cannot end call: \(error)")
                conversation.voiceChannel?.leave()
            }
            completion?()
        }
    }
    
    func reportIncomingCall(from user: ZMUser, in conversation: ZMConversation, video: Bool) {
        
        guard let handle = conversation.callKitHandle else {
            return log("Cannot report incoming call: conversation is missing handle")
        }
        
        guard !conversation.needsToBeUpdatedFromBackend else {
            return log("Cannot report incoming call: conversation needs to be updated from backend")
        }
        
        let update = CXCallUpdate()
        update.supportsHolding = false
        update.supportsDTMF = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.localizedCallerName = conversation.localizedCallerName(with: user)
        update.remoteHandle = handle
        update.hasVideo = video
        
        let callUUID = UUID()
        calls[callUUID] = CallKitCall(conversation: conversation)
        
        log("provider.reportNewIncomingCall")
        
        provider.reportNewIncomingCall(with: callUUID, update: update) { [weak self] (error) in
            if let error = error {
                self?.log("Cannot report incoming call: \(error)")
                self?.calls.removeValue(forKey: callUUID)
                conversation.voiceChannel?.leave()
            } else {
                self?.mediaManager?.setupAudioDevice()
            }
        }
    }
    
    func reportCall(in conversation: ZMConversation, endedAt timestamp: Date?, reason: CXCallEndedReason) {
        
        var associatedCallUUIDs : [UUID] = []
        for call in calls {
            if call.value.conversation == conversation {
                associatedCallUUIDs.append(call.key)
            }
        }
        
        associatedCallUUIDs.forEach { (callUUID) in
            calls.removeValue(forKey: callUUID)
            log("provider.reportCallEndedAt: \(String(describing: timestamp))")
            provider.reportCall(with: callUUID, endedAt: timestamp?.clampForCallKit() ?? Date(), reason: reason)
        }
        
       
        reportCall(in: conversation.remoteIdentifier!, endedAt: timestamp, reason: .unanswered)
    }
    
    func reportCall(in cid: UUID, endedAt timestamp: Date?, reason: CXCallEndedReason) {
        
        var associatedCallUUIDs : [UUID] = []
        for call in stashIncommingCallConvs {
            if call.value.cid == cid {
                associatedCallUUIDs.append(call.key)
            }
        }
        
        associatedCallUUIDs.forEach { (callUUID) in
            stashIncommingCallConvs.removeValue(forKey: callUUID)
            log("provider.reportCallWithCid:EndedAt: \(String(describing: timestamp))")
            provider.reportCall(with: callUUID, endedAt: timestamp?.clampForCallKit() ?? Date(), reason: reason)
        }
    }
}

// MARK: V2
extension CallKitManager {
    
    internal func callUUIDV2(for conversationid: String) -> UUID? {
        guard let cUid = UUID.init(uuidString: conversationid) else {
            return nil
        }
        if let callUID = stashIncommingCallConvs.first(where: { $0.value.cid == cUid })?.key {
            return callUID
        }
        return calls.first(where: { $0.value.conversation.remoteIdentifier == cUid })?.key
    }
    
    func reportIncomingCallV2(from userId: String, userName: String, conversationId: String, video: Bool) {
        let handle = CXHandle(type: .generic, value: userId + String(identifierSeparator) + conversationId)
        
        let update = CXCallUpdate()
        update.supportsHolding = false
        update.supportsDTMF = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.localizedCallerName = userName
        update.remoteHandle = handle
        update.hasVideo = video
        
        let callUUID = UUID()
        self.stashIncommingCallConvs[callUUID] = WaitingConvInfoCall(cid: UUID(uuidString: conversationId)!)

        log("provider.reportNewIncomingCallv2")
        
        provider.reportNewIncomingCall(with: callUUID, update: update) { [weak self] (error) in
            if let error = error {
                self?.log("Cannot report incoming call: \(error)")
                self?.stashIncommingCallConvs.removeValue(forKey: callUUID)
            } else {
                self?.mediaManager?.setupAudioDevice()
            }
        }
    }
    
    func requestEndCallV2(in conversationId: String, completion: (()->())? = nil) {
        guard let callUUID = callUUIDV2(for: conversationId) else { return }
        
        let action = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: action)
        
        log("request CXEndCallActionv2")
        
        callController.request(transaction) { [weak self] (error) in
            if let error = error {
                self?.log("Cannot end call: \(error)")
            }
            completion?()
        }
    }
    
}

fileprivate extension Date {
    func clampForCallKit() -> Date {
        let twoWeeksBefore = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        
        return clamp(between: twoWeeksBefore, and: Date())
    }
    
    func clamp(between fromDate: Date, and toDate: Date) -> Date {
        if timeIntervalSinceReferenceDate < fromDate.timeIntervalSinceReferenceDate {
            return fromDate
        }
        else if timeIntervalSinceReferenceDate > toDate.timeIntervalSinceReferenceDate {
            return toDate
        }
        else {
            return self
        }
    }
}

extension CallKitManager : CXProviderDelegate {
    
    public func providerDidBegin(_ provider: CXProvider) {
        log("providerDidBegin: \(provider)")
    }
    
    public func providerDidReset(_ provider: CXProvider) {
        log("providerDidReset: \(provider)")
        mediaManager?.resetAudioDevice()
        calls.removeAll()
        delegate?.endAllCalls()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        log("perform CXStartCallAction: \(action)")
        
        guard let call = calls[action.callUUID] else {
            log("fail CXStartCallAction because call did not exist")
            action.fail()
            return
        }
        
        call.observer.onAnswered = {
            provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        }
        
        call.observer.onEstablished = {
            provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
        }
        
        mediaManager?.setupAudioDevice()
        
        if call.conversation.voiceChannel?.join(video: action.isVideo) == true {
            action.fulfill()
        } else {
            action.fail()
        }
        
        let update = CXCallUpdate()
        update.remoteHandle = call.conversation.callKitHandle
        update.localizedCallerName = call.conversation.localizedCallerNameForOutgoingCall()
        
        provider.reportCall(with: action.callUUID, updated: update)
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        log("perform CXAnswerCallAction: \(action)")
        
        func canAnswerwhenCallReady(call: CallKitCall, action: CXAnswerCallAction) {
            call.observer.onEstablished = {
                action.fulfill()
            }
            call.observer.onFailedToJoin = {
                action.fail()
            }
            if call.conversation.voiceChannel?.join(video: false) != true {
                action.fail()
            }
        }
        
        if let call = self.calls[action.callUUID] {
            canAnswerwhenCallReady(call: call, action: action)
        } else if let stillWaitingCall = self.stashIncommingCallConvs[action.callUUID] {
            stillWaitingCall.updateState(.answering)
            stillWaitingCall.onWaitingTimeout = {[weak self] in
                guard let self = self else {
                    action.fail()
                    return
                }
                self.stashIncommingCallConvs.removeValue(forKey: action.callUUID)
                action.fail()
            }
            stillWaitingCall.onWaitingSuccess = {[weak self] in
                guard let self = self,
                    let call = self.calls[action.callUUID] else {
                    action.fail()
                    return
                }
                canAnswerwhenCallReady(call: call, action: action)
            }
        } else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        log("perform CXEndCallAction: \(action)")
        
        guard let call = calls[action.callUUID] else {
            log("fail CXEndCallAction because call did not exist")
            action.fail()
            return
        }
        
        calls.removeValue(forKey: action.callUUID)
        call.conversation.voiceChannel?.leave()
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        log("perform CXSetHeldCallAction: \(action)")
        guard let call = calls[action.callUUID] else {
            log("fail CXSetHeldCallAction because call did not exist")
            action.fail()
            return
        }
        
        call.conversation.voiceChannel?.muted = action.isOnHold
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        log("perform CXSetMutedCallAction: \(action)")
        guard let call = calls[action.callUUID] else {
            log("fail CXSetMutedCallAction because call did not exist")
            action.fail()
            return
        }
        
        call.conversation.voiceChannel?.muted = action.isMuted
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        log("didActivate audioSession")
        mediaManager?.startAudio()
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        log("didDeactivate audioSession")
        mediaManager?.resetAudioDevice()
    }
}

extension CallKitManager : WireCallCenterCallStateObserver, WireCallCenterMissedCallObserver {
    
    public func callCenterDidChange(callState: CallState, conversation: ZMConversation, caller: UserType, timestamp: Date?, previousCallState: CallState?) {
        switch callState {
        case .incoming(video: let video, shouldRing: let shouldRing, degraded: _):
            if shouldRing {
                if let waitingCallInfo = self.stashIncommingCallConvs.first(where: { return $0.value.cid == conversation.remoteIdentifier! }) {
                    calls[waitingCallInfo.key] = CallKitCall(conversation: conversation)
                    waitingCallInfo.value.updateState(.finallyWaited)
                    self.stashIncommingCallConvs.removeValue(forKey: waitingCallInfo.key)
                } else {
                    if conversation.mutedMessageTypesIncludingAvailability == .none {
                        reportIncomingCall(from: caller as! ZMUser, in: conversation, video: video)
                    }
                }
            } else {
                reportCall(in: conversation, endedAt: timestamp, reason: .unanswered)
            }
        case let .terminating(reason: reason):
            reportCall(in: conversation, endedAt: timestamp, reason: reason.CXCallEndedReason)
        default:
            break
        }
    }
    
    public func callCenterMissedCall(conversation: ZMConversation, caller: UserType, timestamp: Date, video: Bool) {
        // Since we missed the call we will not have an assigned callUUID and can just create a random one
        provider.reportCall(with: UUID(), endedAt: timestamp, reason: .unanswered)
    }
    
}

extension ZMConversation {
    
    var callKitHandle: CXHandle? {
        if let managedObjectContext = managedObjectContext,
           let userId = ZMUser.selfUser(in: managedObjectContext).remoteIdentifier,
           let remoteIdentifier = remoteIdentifier {
            return CXHandle(type: .generic, value: userId.transportString() + String(identifierSeparator) + remoteIdentifier.transportString())
        }
        
        return nil
    }
    
    func localizedCallerNameForOutgoingCall() -> String? {
        guard let managedObjectContext = self.managedObjectContext  else { return nil }
        
        return localizedCallerName(with: ZMUser.selfUser(in: managedObjectContext))
    }
    
    func localizedCallerName(with user: ZMUser) -> String {
        
        let conversationName = self.userDefinedName
        let callerName : String? = user.name
        var result : String? = nil
        
        switch conversationType {
        case .group:
            if let conversationName = conversationName, let callerName = callerName {
                result = String.localizedStringWithFormat("callkit.call.started.group".pushFormatString, callerName, conversationName)
            } else if let conversationName = conversationName {
                result = String.localizedStringWithFormat("callkit.call.started.group.nousername".pushFormatString, conversationName)
            } else if let callerName = callerName {
                result = String.localizedStringWithFormat("callkit.call.started.group.noconversationname".pushFormatString, callerName)
            }
        case .oneOnOne:
            result = connectedUser?.name
        default:
            break
        }
        
        return result ?? String.localizedStringWithFormat("callkit.call.started.group.nousername.noconversationname".pushFormatString)
    }
    
}

extension CXCallAction {
    
    func conversation(in context : NSManagedObjectContext) -> ZMConversation? {
        return ZMConversation(remoteID: callUUID, createIfNeeded: false, in: context)
    }
    
}

extension CallClosedReason {
    
    var CXCallEndedReason : CXCallEndedReason {
        switch self {
        case .timeout:
            return .unanswered
        case .normal, .canceled:
            return .remoteEnded
        case .anweredElsewhere:
            return .answeredElsewhere
        default:
            return .failed
        }
    }
    
}

class CallObserver : WireCallCenterCallStateObserver {
    
    private var token : Any?
    
    public var onAnswered : (() -> Void)?
    public var onEstablished : (() -> Void)?
    public var onFailedToJoin : (() -> Void)?
    
    public init(conversation: ZMConversation) {
        token = WireCallCenterV3.addCallStateObserver(observer: self, for: conversation, context: conversation.managedObjectContext!)
    }
    
    public func callCenterDidChange(callState: CallState, conversation: ZMConversation, caller: UserType, timestamp: Date?, previousCallState: CallState?) {
        switch callState {
        case .answered(degraded: false):
            onAnswered?()
        case .establishedDataChannel, .established:
            onEstablished?()
        case .terminating(reason: let reason):
            switch reason {
            case .inputOutputError, .internalError, .unknown, .lostMedia, .anweredElsewhere:
                onFailedToJoin?()
            default:
                break
            }
        default:
            break
        }
    }
    
}