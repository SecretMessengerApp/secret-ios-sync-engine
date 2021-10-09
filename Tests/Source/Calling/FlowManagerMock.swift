//

import Foundation

@testable import WireSyncEngine

@objcMembers
public class FlowManagerMock : NSObject, FlowManagerType {
    
    public var callConfigContext : UnsafeRawPointer? = nil
    public var callConfigHttpStatus : Int = 0
    public var callConfig : Data? = nil
    public var didReportCallConfig : Bool = false
    public var didSetVideoCaptureDevice : Bool = false

    override init() {
        super.init()
    }
    
    public func appendLog(for conversationId: UUID, message: String) {
        
    }
    
    public func report(callConfig: Data?, httpStatus: Int, context: UnsafeRawPointer) {
        self.callConfig = callConfig
        callConfigContext = context
        callConfigHttpStatus = httpStatus
        didReportCallConfig = true
    }

    public func setVideoCaptureDevice(_ device: CaptureDevice, for conversationId: UUID) {
        didSetVideoCaptureDevice = true
    }
    
}
