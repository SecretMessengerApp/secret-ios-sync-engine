//

import UIKit
import WireTransport
import WireTesting

/**
 * A controllable objects that mocks the behavior of UIApplication regarding background tasks.
 */

@objc class MockBackgroundActivityManager: NSObject, BackgroundActivityManager {
    
    var backgroundTimeRemaining: TimeInterval = 10
    
    var applicationState: UIApplication.State = .active

    /// Whether the activity is expiring.
    @objc private(set) var isExpiring: Bool = false

    /// A hook to intercept when a task is started.
    @objc var startTaskHandler: ((String?) -> Void)?

    /// A hook to intercept when a task is ended.
    @objc var endTaskHandler: ((String?) -> Void)?

    /// The number of tasks that can be active at the same time. Defaults to 1.
    @objc var limit: Int = 1

    /// The number of active tasks.
    @objc var numberOfTasks: Int {
        return tasks.count
    }

    // MARK: - Data

    private var lastIdentifier: ZMAtomicInteger = ZMAtomicInteger(integer: 1)

    private struct Task {
        let name: String?
        let expirationHandler: (() -> Void)?
    }

    private var tasks: [Int: Task] = [:]

    // MARK: - BackgroundActivityManager

    func beginBackgroundTask(withName name: String?, expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        assert(numberOfTasks + 1 <= limit, "Creating a new task would exceed the limit.")

        if isExpiring {
            return UIBackgroundTaskIdentifier(rawValue: UIBackgroundTaskIdentifier.invalid.rawValue)
        }

        let task = Task(name: name, expirationHandler: expirationHandler)
        let identifier = lastIdentifier.increment()

        tasks[identifier] = task
        startTaskHandler?(name)
        return UIBackgroundTaskIdentifier(rawValue: identifier)
    }

    func endBackgroundTask(_ task: UIBackgroundTaskIdentifier) {
        assert(task != UIBackgroundTaskIdentifier.invalid, "The task is invalid.")

        let name = tasks[task.rawValue]?.name
        tasks[task.rawValue] = nil
        endTaskHandler?(name)
    }

    // MARK: - Helpers

    @objc func triggerExpiration() {
        isExpiring = true

        tasks.values.forEach {
            $0.expirationHandler?()
        }
    }

    @objc func reset() {
        triggerExpiration()
        limit = 1
        isExpiring = false
        tasks.removeAll()
    }

}
