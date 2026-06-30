import PhotosUI
import SwiftUI

struct ChatDetailView: View {
    let chatId: String
    let chatTitle: String

    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var boardVM: BoardViewModel
    @EnvironmentObject private var eventsVM: EventsViewModel

    @State private var draft = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var reportingMessage: Message?
    @FocusState private var inputFocused: Bool

    private var currentUserId: String? { authViewModel.currentUser?.uid }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let chat = chatVM.chats.first(where: { $0.id == chatId }),
                           let postTitle = chat.postTitle, !postTitle.isEmpty {
                            Text("Oglas: \(postTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                                .padding(.top, 8)
                        }

                        ForEach(chatVM.messages) { message in
                            if let id = message.id {
                                MessageBubble(
                                    text: message.text,
                                    imageURL: message.imageURL,
                                    sharedContent: message.sharedContent,
                                    isMine: message.senderId == currentUserId,
                                    time: message.createdAt
                                )
                                .id(id)
                                .contextMenu {
                                    if message.senderId != currentUserId {
                                        Button {
                                            reportingMessage = message
                                        } label: {
                                            Label("Prijavi poruku", systemImage: "flag")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: chatVM.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(Constants.Colors.primary)
                }
                .disabled(chatVM.isSending || currentUserId == nil)

                TextField("Poruka…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)

                if chatVM.isSending {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                    }
                    .disabled(!canSendText)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .background(Constants.Colors.background)
        .navigationTitle(chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SharedContentNavigation.self) { nav in
            sharedContentDestination(nav)
        }
        .onAppear {
            chatVM.startListeningMessages(chatId: chatId)
            if let uid = currentUserId {
                Task { await chatVM.markChatRead(chatId: chatId, userId: uid) }
            }
        }
        .onDisappear {
            chatVM.stopListeningMessages()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await sendPhoto(item)
                selectedPhoto = nil
            }
        }
        .sheet(item: $reportingMessage) { message in
            if let messageId = message.id {
                ReportContentView(
                    targetType: .message,
                    targetId: messageId,
                    targetTitle: messagePreview(message),
                    chatId: chatId,
                    messageId: messageId,
                    messageText: message.text,
                    messageImageURL: message.imageURL,
                    messageSenderId: message.senderId
                )
                .environmentObject(authViewModel)
            }
        }
    }

    private func messagePreview(_ message: Message) -> String {
        if let shared = message.sharedContent {
            return "\(shared.type.label): \(shared.title)"
        }
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return String(text.prefix(80)) }
        if let url = message.imageURL, !url.isEmpty { return "Slika u poruci" }
        return "Poruka"
    }

    @ViewBuilder
    private func sharedContentDestination(_ nav: SharedContentNavigation) -> some View {
        switch nav.type {
        case .post:
            PostDetailView(postId: nav.contentId)
                .environmentObject(boardVM)
                .environmentObject(authViewModel)
                .environmentObject(chatVM)
        case .event:
            EventDetailView(eventId: nav.contentId)
                .environmentObject(eventsVM)
                .environmentObject(authViewModel)
                .environmentObject(chatVM)
        case .feedPost:
            FeedPostDetailView(postId: nav.contentId)
                .environmentObject(authViewModel)
        }
    }

    private var canSendText: Bool {
        guard currentUserId != nil else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() async {
        guard let uid = currentUserId else { return }
        let text = draft
        let ok = await chatVM.sendMessage(chatId: chatId, senderId: uid, text: text)
        if ok {
            draft = ""
            inputFocused = true
        }
    }

    private func sendPhoto(_ item: PhotosPickerItem) async {
        guard let uid = currentUserId,
              let data = await PhotoImport.jpegData(from: item) else { return }
        let caption = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = caption.isEmpty ? nil : caption
        let ok = await chatVM.sendImageMessage(
            chatId: chatId,
            senderId: uid,
            imageData: data,
            caption: text
        )
        if ok {
            draft = ""
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastId = chatVM.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

private struct MessageBubble: View {
    let text: String
    let imageURL: String?
    let sharedContent: SharedContentPayload?
    let isMine: Bool
    let time: Date

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasImage: Bool {
        guard let imageURL, !imageURL.isEmpty else { return false }
        return URL(string: imageURL) != nil
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                    if let sharedContent {
                        NavigationLink(value: SharedContentNavigation(type: sharedContent.type, contentId: sharedContent.contentId)) {
                            SharedContentCardView(payload: sharedContent, compact: true)
                        }
                        .buttonStyle(.plain)
                    }

                    if hasImage, let url = URL(string: imageURL ?? "") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                imagePlaceholder
                            case .empty:
                                ProgressView()
                                    .frame(width: 180, height: 140)
                            @unknown default:
                                imagePlaceholder
                            }
                        }
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if !trimmedText.isEmpty {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(isMine ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isMine ? Constants.Colors.primary : Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Text(time, format: Date.FormatStyle(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }

    private var imagePlaceholder: some View {
        Color(.systemGray5)
            .frame(width: 180, height: 140)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
