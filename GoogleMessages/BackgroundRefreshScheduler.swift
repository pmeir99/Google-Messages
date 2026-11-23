import BackgroundTasks
import Foundation

/// iPadOS controls when this request runs. It only checks site availability;
/// the authenticated inbox is refreshed when the app becomes active.
final class BackgroundRefreshScheduler {
    static let shared = BackgroundRefreshScheduler()
    static let taskIdentifier = "com.pmeir99.GoogleMessages.refresh"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    func schedule() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "messages.backgroundCheckEnabled") != nil,
           !defaults.bool(forKey: "messages.backgroundCheckEnabled") { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // iPadOS can decline or defer background requests.
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()
        let work = Task {
            var request = URLRequest(url: URL(string: "https://messages.google.com/web/")!)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 12
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 500
                task.setTaskCompleted(success: (200..<400).contains(status))
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
}
