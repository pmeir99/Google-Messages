import SwiftUI
import BackgroundTasks

@main
struct GoogleMessagesApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefreshScheduler.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        BackgroundRefreshScheduler.shared.schedule()
                    } else if phase == .active {
                        NotificationCenter.default.post(name: .messagesAppBecameActive, object: nil)
                    }
                }
        }
    }
}

extension Notification.Name {
    static let messagesAppBecameActive = Notification.Name("messagesAppBecameActive")
}
