//

import Foundation

/// Represents the sound for types of notifications.
public enum NotificationSound {

    case call, ping, newMessage

    /// The name of the song.
    public var name: String {
        return customFileName ?? defaultFileName
    }

    // MARK: - Utilities

    private var defaultFileName: String {
        switch self {
        case .call: return "ringing_from_them_long.caf"
        case .ping: return "ping_from_them.caf"
        case .newMessage: return "new_message_apns.caf"
        }
    }

    private var preferenceKey: String {
        switch self {
        case .call: return "ZMCallSoundName"
        case .ping: return "ZMPingSoundName"
        case .newMessage: return "ZMMessageSoundName"
        }
    }

    private var customFileName: String? {
        guard let soundName = UserDefaults.standard.object(forKey: preferenceKey) as? String else { return nil }
        return ZMSound(rawValue: soundName)?.filename()
    }

}
