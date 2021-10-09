//

@testable import WireSyncEngine

class MockPasteboard: Pasteboard {
    var text: String?
    var changeCount: Int = 0
}
