//

import Foundation
import avs

@objc
public protocol FlowManagerType {

    func setVideoCaptureDevice(_ device : CaptureDevice, for conversationId: UUID)
}

@objc
public class FlowManager : NSObject, FlowManagerType {
    public static let AVSFlowManagerCreatedNotification = Notification.Name("AVSFlowManagerCreatedNotification")
    
    fileprivate var mediaManager : MediaManagerType?
    fileprivate var avsFlowManager : AVSFlowManager?

    init(mediaManager: MediaManagerType) {
        super.init()

        self.mediaManager = mediaManager
        self.avsFlowManager = AVSFlowManager(delegate: self, mediaManager: mediaManager)
        NotificationCenter.default.post(name: type(of: self).AVSFlowManagerCreatedNotification, object: self)
    }
    
    public func setVideoCaptureDevice(_ device : CaptureDevice, for conversationId: UUID) {
        avsFlowManager?.setVideoCaptureDevice(device.deviceIdentifier, forConversation: conversationId.transportString())
    }
    
}

// MARK: - AVSFlowManagerDelegate

extension FlowManager : AVSFlowManagerDelegate {
    
    public static func logMessage(_ msg: String!) {
        // no-op
    }
    
    public func request(withPath path: String!, method: String!, mediaType mtype: String!, content: Data!, context ctx: UnsafeRawPointer!) -> Bool {
        // no-op
        return false
    }
    
    public func didEstablishMedia(inConversation convid: String!) {
        // no-op
    }
    
    public func didEstablishMedia(inConversation convid: String!, forUser userid: String!) {
        // no-op
    }
    
    public func setFlowManagerActivityState(_ activityState: AVSFlowActivityState) {
        // no-op
    }
    
    public func networkQuality(_ q: Float, conversation convid: String!) {
        // no-op
    }
    
    public func mediaWarning(onConversation convId: String!) {
        // no-op
    }
    
    public func errorHandler(_ err: Int32, conversationId convid: String!, context ctx: UnsafeRawPointer!) {
        // no-op
    }
    
    public func didUpdateVolume(_ volume: Double, conversationId convid: String!, participantId: String!) {
        // no-op
    }
    
}
