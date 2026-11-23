import SwiftUI

struct AppSettingsView: View {
    @Binding var zoom: Double
    @ObservedObject var connectivity: ConnectivityMonitor
    let onOpenMessages: () -> Void
    @AppStorage("messages.backgroundCheckEnabled") private var backgroundCheckEnabled = true

    var body: some View {
        Form {
            Section("Web view") {
                HStack {
                    Text("Page zoom")
                    Spacer()
                    Text("\(Int(zoom * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $zoom, in: 0.8...1.4, step: 0.05)
                    .accessibilityLabel("Page zoom")
                Text("Pinch to zoom in the page, or use the zoom buttons in the toolbar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Pairing and session") {
                Label("Session saved in this app", systemImage: "lock.shield")
                Text("Google Messages stores its site data in this app's private WebKit store. It does not share Safari's signed-in session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("Use account sign-in or QR pairing", systemImage: "qrcode")
                Text("Google's web page controls sign-in and pairing. To pair with a phone, open the QR pairing option and scan it from the phone's Messages app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Background refresh") {
                Toggle("Allow background availability checks", isOn: $backgroundCheckEnabled)
                    .onChange(of: backgroundCheckEnabled) { _, enabled in
                        if enabled { BackgroundRefreshScheduler.shared.schedule() }
                    }
                Text("iPadOS may run a brief site availability check while the app is in the background. It cannot keep the web client continuously active; the inbox refreshes when you return to the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Connection") {
                LabeledContent("Internet", value: connectivity.isOnline ? "Connected" : "Offline")
                Button("Open Google Messages") {
                    onOpenMessages()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("App Settings")
    }
}
