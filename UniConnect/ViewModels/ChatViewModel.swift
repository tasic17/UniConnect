import Combine
import FirebaseFirestore
import Foundation

final class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published private(set) var participantNameCache: [String: String] = [:]
    @Published private(set) var participantPhotoURLCache: [String: String] = [:]

    /// Otvori tab Poruke i navigiraj na razgovor (npr. sa oglasa).
    @Published var pendingOpenChatId: String?

    private var chatsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var listeningUserId: String?
    private var activeChatId: String?

    @MainActor
    func ensureChatsListening(userId: String) {
        guard listeningUserId != userId else { return }
        stopListeningChats()
        listeningUserId = userId
        isLoading = chats.isEmpty

        chatsListener = FirestoreService.shared.listenChats(userId: userId) { [weak self] list in
            Task { @MainActor in
                guard let self else { return }
                self.chats = list
                self.isLoading = false
                await self.prefetchParticipantProfiles(for: list, currentUserId: userId)
            }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.isLoading = false
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    func stopListeningChats() {
        chatsListener?.remove()
        chatsListener = nil
        listeningUserId = nil
    }

    @MainActor
    func startListeningMessages(chatId: String) {
        guard activeChatId != chatId else { return }
        stopListeningMessages()
        activeChatId = chatId
        messages = []

        messagesListener = FirestoreService.shared.listenMessages(chatId: chatId) { [weak self] list in
            Task { @MainActor in
                self?.messages = list
            }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    func stopListeningMessages() {
        messagesListener?.remove()
        messagesListener = nil
        activeChatId = nil
        messages = []
    }

    @MainActor
    func openChat(
        currentUserId: String,
        otherUserId: String,
        postId: String?,
        postTitle: String?
    ) async -> String? {
        guard currentUserId != otherUserId else {
            errorMessage = "Ne možeš poslati poruku samom sebi."
            return nil
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let chatId = try await FirestoreService.shared.findOrCreateChat(
                currentUserId: currentUserId,
                otherUserId: otherUserId,
                postId: postId,
                postTitle: postTitle
            )
            ensureChatsListening(userId: currentUserId)
            return chatId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func requestOpenChat(chatId: String) {
        pendingOpenChatId = chatId
    }

    @MainActor
    func clearPendingOpenChat() {
        pendingOpenChatId = nil
    }

    @MainActor
    func sendMessage(chatId: String, senderId: String, text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let chat = chats.first(where: { $0.id == chatId }),
              let recipientId = chat.otherParticipantId(than: senderId) else {
            errorMessage = "Razgovor nije učitan."
            return false
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await FirestoreService.shared.sendMessage(
                chatId: chatId,
                senderId: senderId,
                recipientId: recipientId,
                text: trimmed,
                imageURL: nil
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func sendSharedContent(
        currentUserId: String,
        recipientId: String,
        type: SharedContentType,
        contentId: String,
        title: String,
        comment: String? = nil
    ) async -> String? {
        guard currentUserId != recipientId else {
            errorMessage = "Ne možeš poslati poruku samom sebi."
            return nil
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let chatId = try await FirestoreService.shared.findOrCreateChat(
                currentUserId: currentUserId,
                otherUserId: recipientId,
                postId: nil,
                postTitle: nil
            )
            try await FirestoreService.shared.sendMessage(
                chatId: chatId,
                senderId: currentUserId,
                recipientId: recipientId,
                text: comment,
                imageURL: nil,
                sharedType: type,
                sharedId: contentId,
                sharedTitle: title
            )
            ensureChatsListening(userId: currentUserId)
            return chatId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func sendImageMessage(chatId: String, senderId: String, imageData: Data, caption: String? = nil) async -> Bool {
        guard let chat = chats.first(where: { $0.id == chatId }),
              let recipientId = chat.otherParticipantId(than: senderId) else {
            errorMessage = "Razgovor nije učitan."
            return false
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let imageURL = try await StorageService.shared.uploadChatImage(chatId: chatId, data: imageData)
            try await FirestoreService.shared.sendMessage(
                chatId: chatId,
                senderId: senderId,
                recipientId: recipientId,
                text: caption,
                imageURL: imageURL
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func deleteChat(chatId: String, userId: String) async -> Bool {
        errorMessage = nil
        do {
            try await FirestoreService.shared.deleteChat(chatId: chatId, userId: userId)
            if activeChatId == chatId {
                stopListeningMessages()
            }
            chats.removeAll { $0.id == chatId }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func markChatRead(chatId: String, userId: String) async {
        do {
            try await FirestoreService.shared.markChatRead(chatId: chatId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func totalUnread(for userId: String) -> Int {
        chats.reduce(0) { $0 + $1.unreadCount(for: userId) }
    }

    func listingChats() -> [Chat] {
        chats.filter(\.isListingChat)
    }

    func directChats() -> [Chat] {
        chats.filter { !$0.isListingChat }
    }

    @MainActor
    func participantPhotoURL(for userId: String) -> String? {
        let u = participantPhotoURLCache[userId] ?? ""
        return u.isEmpty ? nil : u
    }

    @MainActor
    func displayName(for userId: String, currentUserId: String) -> String {
        if userId == currentUserId { return "Ti" }
        return participantNameCache[userId] ?? "Korisnik"
    }

    @MainActor
    func chatTitle(for chat: Chat, currentUserId: String) -> String {
        if let otherId = chat.otherParticipantId(than: currentUserId) {
            return displayName(for: otherId, currentUserId: currentUserId)
        }
        return chat.postTitle ?? "Razgovor"
    }

    @MainActor
    func refreshParticipantProfile(userId: String) async {
        guard !userId.isEmpty else { return }
        let name: String
        let photo: String
        if let user = try? await AuthService.shared.fetchUser(uid: userId) {
            name = user.displayName
            photo = user.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            name = "Korisnik"
            photo = ""
        }
        participantNameCache[userId] = name
        participantPhotoURLCache[userId] = photo
    }

    @MainActor
    private func prefetchParticipantProfiles(for chats: [Chat], currentUserId: String) async {
        let ids = Set(chats.flatMap(\.participants)).subtracting([currentUserId])
        await withTaskGroup(of: Void.self) { group in
            for uid in ids {
                group.addTask { [weak self] in
                    await self?.refreshParticipantProfile(userId: uid)
                }
            }
        }
    }
}
