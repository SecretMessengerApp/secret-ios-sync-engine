////

import Foundation
import WireTransport

extension ZMUpdateEvent {
    public convenience override init() {
        self.init(uuid: nil, payload: ["type": "conversation.create"], transient: false, decrypted: false, source: .download)!
    }

    @objc static func dummy() -> ZMUpdateEvent {
        return ZMUpdateEvent()
    }
}
