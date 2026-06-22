import Foundation
import FirebaseFirestore

/// Dokument u `users/{uid}/following/{targetUserId}`.
struct UserFollow: Codable, Identifiable {
    @DocumentID var id: String?
    var targetUserId: String
    var displayName: String
    var profileImageURL: String?
    var createdAt: Date

    init(
        id: String? = nil,
        targetUserId: String,
        displayName: String,
        profileImageURL: String? = nil,
        createdAt: Date = Date()
    ) {
        _id = DocumentID(wrappedValue: id)
        self.targetUserId = targetUserId
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.createdAt = createdAt
    }
}
