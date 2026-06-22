import Foundation
import FirebaseFirestore

struct Chat: Codable, Identifiable {
    @DocumentID var id: String?
    var participants: [String]
    /// Jedinstveni ključ za pretragu (sortirani UID-ovi + opciono `postId`).
    var participantKey: String
    var postId: String?
    var postTitle: String?
    var lastMessage: String
    var lastMessageAt: Date
    var createdAt: Date
    /// Broj nepročitanih poruka po učesniku (`uid` → count).
    var unreadCounts: [String: Int]?

    static func participantKey(for userIds: [String], postId: String?) -> String {
        let base = userIds.sorted().joined(separator: "_")
        guard let postId, !postId.isEmpty else { return base }
        return "\(base)_post_\(postId)"
    }

    init(
        id: String? = nil,
        participants: [String],
        participantKey: String,
        postId: String? = nil,
        postTitle: String? = nil,
        lastMessage: String,
        lastMessageAt: Date,
        createdAt: Date,
        unreadCounts: [String: Int]? = nil
    ) {
        _id = DocumentID(wrappedValue: id)
        self.participants = participants
        self.participantKey = participantKey
        self.postId = postId
        self.postTitle = postTitle
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.unreadCounts = unreadCounts
    }

    /// Razgovor vezan za oglas (`postId` postoji).
    var isListingChat: Bool {
        guard let postId = postId?.trimmingCharacters(in: .whitespacesAndNewlines), !postId.isEmpty else {
            return false
        }
        return true
    }

    func unreadCount(for userId: String) -> Int {
        unreadCounts?[userId] ?? 0
    }

    func otherParticipantId(than userId: String) -> String? {
        participants.first { $0 != userId }
    }
}

