import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var engine = MessagesWebEngine()
    @StateObject private var connectivity = ConnectivityMonitor()
    @AppStorage("messages.appearance") private var appearance = "system"
    @State private var selected: MessageConversation?
    @State private var query = ""
    @State private var filter: InboxFilter = .all
    @State private var showCompose = false
    @State private var showSettings = false
    @State private var showGooglePage = false

    private var filtered: [MessageConversation] {
        engine.conversations.filter { conversation in
            let matchesQuery = query.isEmpty || conversation.title.localizedCaseInsensitiveContains(query) || conversation.preview.localizedCaseInsensitiveContains(query)
            let matchesFilter = filter == .all || (filter == .unread && conversation.unread) || (filter == .groups && conversation.group)
            return matchesQuery && matchesFilter
        }
    }

    var body: some View {
        Group {
            if showGooglePage || !engine.connected {
                googleSessionView
            } else {
                nativeInbox
            }
        }
        .task {
            BackgroundRefreshScheduler.shared.schedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: .messagesAppBecameActive)) { _ in
            BackgroundRefreshScheduler.shared.schedule()
        }
        .sheet(isPresented: $showCompose) {
            ComposeView(conversations: engine.conversations) { conversation in
                selected = conversation
                showCompose = false
            } onNewRecipient: {
                showCompose = false
                engine.startNewConversation()
                showGooglePage = true
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                AppSettingsView(connectivity: connectivity) {
                    showSettings = false
                    showGooglePage = true
                }
            }
            .presentationDetents([.medium, .large])
        }
        .tint(Color(red: 0.16, green: 0.38, blue: 0.88))
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
    }

    private var nativeInbox: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Messages").font(.largeTitle.bold())
                    Spacer()
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil").font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("New message")
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                Picker("Filter conversations", selection: $filter) {
                    ForEach(InboxFilter.allCases) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

                List {
                    ForEach(filtered) { conversation in
                        Button {
                            selected = conversation
                            engine.selectConversation(conversation)
                        } label: {
                            ConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12))
                        .listRowBackground(selected?.id == conversation.id ? Color.blue.opacity(0.10) : Color.clear)
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if filtered.isEmpty {
                        ContentUnavailableView(query.isEmpty ? "No conversations" : "No results", systemImage: "bubble.left.and.bubble.right", description: Text(query.isEmpty ? "Sign in or pair your phone with Google Messages." : "Try another name or phrase."))
                    }
                }
                HStack(spacing: 8) {
                    Circle().fill(connectivity.isOnline ? .green : .orange).frame(width: 8, height: 8)
                    Text(connectivity.isOnline ? "Connected" : "Offline")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 430)
        } detail: {
            if let selected {
                ConversationDetailView(conversation: selected, engine: engine)
            } else {
                ContentUnavailableView("Your messages", systemImage: "bubble.left.and.bubble.right", description: Text("Choose a conversation or start a new message."))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background {
            if engine.connected && !showGooglePage {
                MessagesWebHost(engine: engine, visible: false).frame(width: 1, height: 1).opacity(0.01)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    NotificationCenter.default.post(name: .messagesReloadRequested, object: nil)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh conversations")
                .accessibilityLabel("Refresh conversations")
                Button { showGooglePage = true } label: { Image(systemName: "globe") }
                    .help("Open Google Messages web client")
                    .accessibilityLabel("Open Google Messages web client")
            }
        }
    }

    private var googleSessionView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MessagesWebHost(engine: engine, visible: true).ignoresSafeArea(edges: .bottom)
                if engine.connected {
                    Label("Switching to iPad Messages", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 18)
                }
            }
            .navigationTitle("Google account & pairing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { if engine.connected { showGooglePage = false } }
                        .disabled(!engine.connected)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { NotificationCenter.default.post(name: .messagesReloadRequested, object: nil) } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Reload Google Messages")
                }
            }
        }
    }
}

private enum InboxFilter: String, CaseIterable, Identifiable {
    case all, unread, groups
    var id: String { rawValue }
    var title: String {
        switch self { case .all: "All"; case .unread: "Unread"; case .groups: "Groups" }
    }
}

private struct ConversationRow: View {
    let conversation: MessageConversation
    var body: some View {
        HStack(spacing: 12) {
            ConversationAvatar(conversation: conversation, size: 50)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title).font(.body.weight(conversation.unread ? .semibold : .medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(conversation.time).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    if conversation.group { Image(systemName: "person.2.fill").font(.caption2) }
                    Text(conversation.preview.isEmpty ? " " : conversation.preview)
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                    if conversation.unread { Circle().fill(.blue).frame(width: 8, height: 8) }
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

struct ConversationAvatar: View {
    let conversation: MessageConversation
    var size: CGFloat

    var body: some View {
        Group {
            if let raw = conversation.avatarURL, let url = URL(string: raw) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Circle().fill(Color.blue.gradient)
            .overlay(Text(String(conversation.title.prefix(1)).uppercased())
                .font(.headline).foregroundStyle(.white))
    }
}

private struct ComposeView: View {
    let conversations: [MessageConversation]
    let onSelect: (MessageConversation) -> Void
    let onNewRecipient: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [MessageConversation] {
        guard !query.isEmpty else { return conversations }
        return conversations.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Choose a conversation to continue", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Recent") {
                    ForEach(results) { conversation in
                        Button { onSelect(conversation) } label: { ConversationRow(conversation: conversation) }
                            .buttonStyle(.plain)
                    }
                }
                Section {
                    Button(action: onNewRecipient) {
                        Label("Message a phone number or contact", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            .searchable(text: $query, prompt: "Name or number")
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }
}
