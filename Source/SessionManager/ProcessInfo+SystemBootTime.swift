//

public extension ProcessInfo {
    var systemBootTime: Date {
        return Date() - systemUptime
    }
}
