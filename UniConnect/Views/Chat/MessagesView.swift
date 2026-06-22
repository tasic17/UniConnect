import SwiftUI

private enum MessagesInboxSection: String, CaseIterable, Identifiable {
    case direct = "Razgovori"
    case listings = "Oglasi"

    var id: String { rawValue }
}

struct MessagesView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var followVM: FollowViewModel
    @EnvironmentObject private var authorCache: AuthorProfileCache
    @Binding var selectedTab: MainTab

    @State private var navigationPath = NavigationPath()
    @State private var inboxSection: MessagesInboxSection = .direct
    @State private var showNewChatSearch = false
    @State private var isSelectingChats = false
    @State private var selectedChatIds: Set<String> = []
    @State private var showDeleteConfirm = false
    @State private var chatIdToDelete: String?

    private var currentChats: [Chat] {
        switch inboxSection {
        case .direct: return chatVM.directChats()
        case .listings: return chatVM.listingChats()
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                Picker("Tip poruka", selection: $inboxSection) {
                    ForEach(MessagesInboxSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onChange(of: inboxSection) { _, _ in
                    cancelSelection()
                }

                Group {
                    if authViewModel.currentUser == nil {
                        signedOutPlaceholder
                    } else if chatVM.isLoading && chatVM.chats.isEmpty {
                        ProgressView("Učitavanje razgovora…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if currentChats.isEmpty {
                        emptyPlaceholder
                    } else {
                        List {
                            ForEach(currentChats) { chat in
                                if let chatId = chat.id,
                                   let uid = authViewModel.currentUser?.uid {
                                    chatRow(chat: chat, chatId: chatId, uid: uid)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .environment(\.defaultMinListRowHeight, 1)
                    }
                }
            }
            .background(Constants.Colors.background)
            .navigationTitle(isSelectingChats ? "Izaberi razgovore" : "Poruke")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if authViewModel.currentUser != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        if isSelectingChats {
                            Button("Otkaži") { cancelSelection() }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if isSelectingChats {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(selectedChatIds.isEmpty)
                            .accessibilityLabel("Obriši izabrane")
                        } else {
                            Button {
                                isSelectingChats = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Obriši razgovore")

                            if inboxSection == .direct {
                                Button {
                                    showNewChatSearch = true
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .accessibilityLabel("Novo ćaskanje")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewChatSearch) {
                NavigationStack {
                    UserSearchView(mode: .pickFollowedForChat) { userId in
                        Task { await startChat(with: userId) }
                    }
                    .environmentObject(authViewModel)
                    .environmentObject(followVM)
                    .environmentObject(authorCache)
                }
            }
            .navigationDestination(for: String.self) { chatId in
                ChatDetailView(chatId: chatId, chatTitle: titleForChatId(chatId))
            }
            .alert("Greška", isPresented: errorBinding, actions: {
                Button("OK", role: .cancel) { chatVM.errorMessage = nil }
            }, message: {
                if let msg = chatVM.errorMessage {
                    Text(msg)
                }
            })
            .alert("Obriši razgovor?", isPresented: $showDeleteConfirm) {
                Button("Obriši", role: .destructive) {
                    Task { await deleteSelectedOrPending() }
                }
                Button("Otkaži", role: .cancel) {
                    chatIdToDelete = nil
                }
            } message: {
                if let chatIdToDelete {
                    Text("Razgovor i sve poruke biće trajno obrisani.")
                } else {
                    Text("Izabrani razgovori (\(selectedChatIds.count)) biće trajno obrisani.")
                }
            }
            .task(id: authViewModel.currentUser?.uid) {
                guard let uid = authViewModel.currentUser?.uid else { return }
                chatVM.ensureChatsListening(userId: uid)
            }
            .onChange(of: chatVM.pendingOpenChatId) { _, chatId in
                guard let chatId else { return }
                selectedTab = .messages
                if let chat = chatVM.chats.first(where: { $0.id == chatId }) {
                    inboxSection = chat.isListingChat ? .listings : .direct
                }
                navigationPath.append(chatId)
                chatVM.clearPendingOpenChat()
            }
            .onAppear {
                if let chatId = chatVM.pendingOpenChatId {
                    if let chat = chatVM.chats.first(where: { $0.id == chatId }) {
                        inboxSection = chat.isListingChat ? .listings : .direct
                    }
                    navigationPath.append(chatId)
                    chatVM.clearPendingOpenChat()
                }
            }
        }
    }

    @ViewBuilder
    private func chatRow(chat: Chat, chatId: String, uid: String) -> some View {
        let otherId = chat.otherParticipantId(than: uid)
        let title = chatTitle(for: chat, uid: uid)
        let unread = chat.unreadCount(for: uid)
        let isSelected = selectedChatIds.contains(chatId)
        let avatarURL = otherId.flatMap { resolvedAvatarURL(for: $0) }

        Group {
            if isSelectingChats {
                Button {
                    toggleSelection(chatId: chatId)
                } label: {
                    ChatRow(
                        chat: chat,
                        title: title,
                        subtitle: chat.lastMessage,
                        avatarURL: avatarURL,
                        avatarName: title,
                        unreadCount: unread,
                        showsSelection: true,
                        isSelected: isSelected
                    )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: chatId) {
                    ChatRow(
                        chat: chat,
                        title: title,
                        subtitle: chat.lastMessage,
                        avatarURL: avatarURL,
                        avatarName: title,
                        unreadCount: unread,
                        showsSelection: false,
                        isSelected: false
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        chatIdToDelete = chatId
                        showDeleteConfirm = true
                    } label: {
                        Label("Obriši", systemImage: "trash")
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
        .task(id: otherId) {
            guard let otherId else { return }
            await authorCache.refresh(authorId: otherId)
            await chatVM.refreshParticipantProfile(userId: otherId)
        }
    }

    private var signedOutPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Prijavi se da vidiš poruke")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: inboxSection == .listings ? "square.grid.2x2" : "message")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(inboxSection == .listings ? "Nema poruka o oglasima" : "Nema razgovora")
                .font(.headline)
            Text(inboxSection == .listings
                 ? "Kontaktiraj prodavca preko „Pošalji poruku” na oglasu."
                 : "Dodirni ikonu olovke da započneš ćaskanje sa nekim koga pratiš.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chatTitle(for chat: Chat, uid: String) -> String {
        guard let otherId = chat.otherParticipantId(than: uid) else {
            return chat.postTitle ?? "Razgovor"
        }
        let fallback = chatVM.displayName(for: otherId, currentUserId: uid)
        return authorCache.resolvedName(for: otherId, fallback: fallback)
    }

    private func resolvedAvatarURL(for userId: String) -> String? {
        authorCache.photoURL(for: userId) ?? chatVM.participantPhotoURL(for: userId)
    }

    private func titleForChatId(_ chatId: String) -> String {
        guard let chat = chatVM.chats.first(where: { $0.id == chatId }),
              let uid = authViewModel.currentUser?.uid else {
            return "Razgovor"
        }
        return chatTitle(for: chat, uid: uid)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { chatVM.errorMessage != nil },
            set: { if !$0 { chatVM.errorMessage = nil } }
        )
    }

    private func toggleSelection(chatId: String) {
        if selectedChatIds.contains(chatId) {
            selectedChatIds.remove(chatId)
        } else {
            selectedChatIds.insert(chatId)
        }
    }

    private func cancelSelection() {
        isSelectingChats = false
        selectedChatIds = []
        chatIdToDelete = nil
    }

    private func deleteSelectedOrPending() async {
        guard let uid = authViewModel.currentUser?.uid else { return }
        let ids: [String]
        if let single = chatIdToDelete {
            ids = [single]
        } else {
            ids = Array(selectedChatIds)
        }
        for chatId in ids {
            _ = await chatVM.deleteChat(chatId: chatId, userId: uid)
        }
        chatIdToDelete = nil
        cancelSelection()
    }

    private func startChat(with userId: String) async {
        guard let uid = authViewModel.currentUser?.uid else { return }
        if let chatId = await chatVM.openChat(
            currentUserId: uid,
            otherUserId: userId,
            postId: nil,
            postTitle: nil
        ) {
            selectedTab = .messages
            chatVM.requestOpenChat(chatId: chatId)
        }
    }
}

private struct ChatRow: View {
    let chat: Chat
    let title: String
    let subtitle: String
    let avatarURL: String?
    let avatarName: String
    let unreadCount: Int
    var showsSelection: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsSelection {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Constants.Colors.primary : .secondary)
            }

            ProfileAvatarImage(imageURL: avatarURL, name: avatarName, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if unreadCount > 0 {
                        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    Text(chat.lastMessageAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let postTitle = chat.postTitle, !postTitle.isEmpty {
                    Text(postTitle)
                        .font(.caption)
                        .foregroundStyle(Constants.Colors.primary)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                    .fontWeight(unreadCount > 0 ? .medium : .regular)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}
