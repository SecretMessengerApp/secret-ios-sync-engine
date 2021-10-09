//

import Foundation

@objc
class MockMediaManager: NSObject, MediaManagerType {
    
    func setUiStartsAudio(_ enabled: Bool) {
        // no-op
    }
    
    var didStartAudio: Bool = false
    func startAudio() {
        didStartAudio = true
    }
    
    var didSetupAudioDevice = false
    func setupAudioDevice() {
        didSetupAudioDevice = true
    }
    
    var didResetAudioDevice = false
    func resetAudioDevice() {
        didResetAudioDevice = true
    }
    
}
