import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var connectivity: ConnectivityMonitor
    let onOpenMessages: () -> Void
    @AppStorage("messages.appearance") private var appearance = "system"
    @AppStorage("messages.backgroundCheckEnabled") private var backgroundCheckEnabled = true

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                Text("The conversation list, chat bubbles, picker, and controls follow the selected iPad appearance.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Account and pairing") {
                Label("Session stored in this app", systemImage: "lock.shield")
                Text("Google's site data is held in this app's private WebKit store, separate from Safari.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(action: onOpenMessages) {
                    Label("Sign in or pair your phone", systemImage: "iphone.and.arrow.forward")
                }
                Text("Google handles account sign-in and phone pairing in its secure web flow. The available pairing method depends on Google's current options for your account and region.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Notifications and background") {
                Label("Google notifications", systemImage: "bell")
                Text("Google Messages does not provide this app with a supported push-notification feed. iPadOS may suspend apps in the background, so messages refresh when the app is active again.")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("Allow background availability checks", isOn: $backgroundCheckEnabled)
                    .onChange(of: backgroundCheckEnabled) { _, enabled in
                        if enabled { BackgroundRefreshScheduler.shared.schedule() } else { BackgroundRefreshScheduler.shared.cancel() }
                    }
                Text("This checks whether the Google Messages website responds when iPadOS grants a short background task. It cannot keep a live connection running.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Connection and compatibility") {
                LabeledContent("Internet", value: connectivity.isOnline ? "Connected" : "Offline")
                Button(action: onOpenMessages) { Label("Open Google Messages web client", systemImage: "globe") }
                Text("Use the Google page for account recovery, pairing, and features that Google does not expose to the native interface.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
