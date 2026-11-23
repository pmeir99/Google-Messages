import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ConversationDetailView: View {
    let conversation: MessageConversation
    @ObservedObject var engine: MessagesWebEngine
    @State private var draft = ""
    @State private var showEmojiPicker = false
    @State private var showFileImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var composerFocused: Bool

    private var visibleMessages: [MessageItem] {
        guard engine.activeTitle.isEmpty || engine.activeTitle.localizedCaseInsensitiveContains(conversation.title) else { return [] }
        return engine.messages
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: visibleMessages.count) { _, _ in
                    if let last = visibleMessages.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            composer
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear { engine.selectConversation(conversation) }
        .onChange(of: conversation.id) { _, _ in engine.selectConversation(conversation) }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let type = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                    engine.sendAttachment(data, mime: type, name: "photo")
                }
                selectedPhoto = nil
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                engine.sendAttachment(data, mime: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", name: url.lastPathComponent)
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPicker { emoji in
                draft.append(emoji)
                showEmojiPicker = false
                composerFocused = true
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { composerFocused = false }
            }
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            ConversationAvatar(conversation: conversation, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title).font(.headline)
                Text(conversation.group ? "Group conversation" : "Google Messages")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.bar)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Menu {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Photo Library", systemImage: "photo")
                }
                Button { showFileImporter = true } label: { Label("Choose File", systemImage: "folder") }
            } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 27)).foregroundStyle(.blue)
            }
            .accessibilityLabel("Add attachment")

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Text Message", text: $draft, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.vertical, 9)
                Button { showEmojiPicker = true } label: { Image(systemName: "face.smiling").font(.title3).foregroundStyle(.secondary) }
                    .accessibilityLabel("Choose emoji")
            }
            .padding(.horizontal, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(uiColor: .separator).opacity(0.3)))
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.bar)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        engine.send(text)
        draft = ""
    }
}

private struct MessageBubble: View {
    let message: MessageItem
    var body: some View {
        HStack {
            if message.outgoing { Spacer(minLength: 70) }
            VStack(alignment: message.outgoing ? .trailing : .leading, spacing: 4) {
                if !message.text.isEmpty {
                    Text(message.text)
                        .textSelection(.enabled)
                        .font(.body)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(message.outgoing ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .foregroundStyle(message.outgoing ? .white : .primary)
                }
                if let attachment = message.attachment {
                    Label(attachment, systemImage: "paperclip")
                        .font(.subheadline).padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                HStack(spacing: 5) {
                    if !message.time.isEmpty { Text(message.time) }
                    if message.outgoing && !message.status.isEmpty { Text(message.status) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            if !message.outgoing { Spacer(minLength: 70) }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmojiPicker: View {
    let onSelect: (String) -> Void
    private let emojis = ["😀","😂","🥰","😍","😊","😉","😭","😎","🤔","🙌","👍","❤️","🎉","🙏","🔥","✨","😘","😅","🥹","💯","👏","🤝","👋","✅","🎂","☀️","🌹","🤗","😴","🤦"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 6)
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) { onSelect(emoji) }.font(.system(size: 30)).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Emoji")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
