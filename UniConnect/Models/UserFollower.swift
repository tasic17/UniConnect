import Foundation
import FirebaseFirestore

/// Dokument u `users/{uid}/followers/{followerUserId}`.
struct UserFollower: Codable, Identifiable {
    @DocumentID var id: String?
    var followerUserId: String
    var displayName: String
    var profileImageURL: String?
    var createdAt: Date

    init(
        id: String? = nil,
        followerUserId: String,
        displayName: String,
        profileImageURL: String? = nil,
        createdAt: Date = Date()
    ) {
        _id = DocumentID(wrappedValue: id)
        self.followerUserId = followerUserId
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.createdAt = createdAt
    }
}
