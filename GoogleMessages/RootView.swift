import SwiftUI
import Network
import UIKit

struct RootView: View {
    @AppStorage("messages.webZoom") private var webZoom = 1.0
    @AppStorage("messages.hasSeenWelcome") private var hasSeenWelcome = false
    @State private var selectedSection: MessagesSection? = .inbox
    @State private var showWelcome = false
    @State private var isLoading = false
    @State private var loadError: String?
    @StateObject private var connectivity = ConnectivityMonitor()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Google Messages") {
                    ForEach(MessagesSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.symbol)
                            .tag(Optional(section))
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(connectivity.isOnline ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(connectivity.isOnline ? "Internet connected" : "Offline")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        } detail: {
            if selectedSection == .settings {
                AppSettingsView(zoom: $webZoom, connectivity: connectivity) { selectedSection = .inbox }
            } else {
                messagesPane
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            if !hasSeenWelcome { showWelcome = true }
            BackgroundRefreshScheduler.shared.schedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: .messagesAppBecameActive)) { _ in
            if selectedSection != .settings {
                selectedSection = .inbox
                loadError = nil
                NotificationCenter.default.post(name: .messagesReloadRequested, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .messagesWebViewLoaded)) { _ in
            isLoading = false
            loadError = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .messagesWebViewFailed)) { notification in
            isLoading = false
            loadError = notification.object as? String
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView {
                hasSeenWelcome = true
                showWelcome = false
                selectedSection = .inbox
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .tint(Color(red: 0.22, green: 0.36, blue: 0.88))
    }

    private var messagesPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Messages")
                        .font(.headline)
                    Text(connectivity.isOnline ? "Connected to the web client" : "Reconnect to load messages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                if isLoading {
                    ProgressView().controlSize(.small)
                }
                Button {
                    reloadPage()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh messages")
                Button {
                    webZoom = max(0.8, webZoom - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out")
                .accessibilityLabel("Zoom out")
                Button {
                    webZoom = min(1.4, webZoom + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom in")
                .accessibilityLabel("Zoom in")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)

            if loadError != nil && !connectivity.isOnline {
                ContentUnavailableView("You're offline", systemImage: "wifi.slash", description: Text("Reconnect to the internet, then refresh Google Messages."))
                    .frame(maxHeight: 180)
            } else if let loadError {
                ContentUnavailableView("Couldn't load Messages", systemImage: "exclamationmark.arrow.triangle.2.circlepath", description: Text(loadError))
                    .frame(maxHeight: 180)
            }

            MessagesWebView(section: selectedSection ?? .inbox, zoom: webZoom, connectivity: connectivity)
                .id("google-messages-webview")
                .overlay(alignment: .top) {
                    if !connectivity.isOnline {
                        Label("Offline", systemImage: "wifi.slash")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 10)
                    }
                }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear { isLoading = true }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    private func reloadPage() {
        isLoading = true
        loadError = nil
        NotificationCenter.default.post(name: .messagesReloadRequested, object: nil)
    }
}

private struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Messages, made for iPad")
                .font(.largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Sign in to Google or pair your phone with the QR code shown by Google Messages. Your web session is saved inside this app, separately from Safari.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button(action: onContinue) {
                Text("Continue to Google Messages")
                    .font(.headline)
                    .frame(maxWidth: 360)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            Text("Keep your phone connected to the internet for linked-device messaging.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

extension Notification.Name {
    static let messagesReloadRequested = Notification.Name("messagesReloadRequested")
}
