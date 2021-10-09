//

import Foundation
import avs

@objc
public protocol MediaManagerType: class {
 
    func setUiStartsAudio(_ enabled: Bool)
    func startAudio()
    func setupAudioDevice()
    func resetAudioDevice()
    
}

extension AVSMediaManager: MediaManagerType { }
