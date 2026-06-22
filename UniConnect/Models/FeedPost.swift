import Foundation
import FirebaseFirestore

/// Jedan dokument u `feed_posts`: korenska objava (`parentId == nil`) ili odgovor u thread-u.
struct FeedPost: Codable, Identifiable {
    @DocumentID var id: String?
    var content: String
    var authorId: String
    var authorName: String
    /// Denormalizovano sa `users` pri objavi (URL profilne ili `nil`).
    var authorProfileImageURL: String?
    var authorDepartment: String
    var targetDepartment: String?
    var likesCount: Int
    var likes: [String]
    var createdAt: Date
    /// URL-ovi slika u Storage (`feed_posts/{id}/…`); stariji dokumenti nemaju polje.
    var imageURLs: [String]?

    /// `nil` = korenski post u feed-u; inače ID dokumenta na koji se direktno odgovara.
    var parentId: String?
    /// ID korenske objave thread-a; kod korena `nil`.
    var threadRootId: String?
    /// Broj odgovora ispod korena (samo smisleno za korenski post).
    var replyCount: Int?

    /// Za prikaz i sortiranje — stariji dokumenti možda nemaju `replyCount`.
    var displayReplyCount: Int { replyCount ?? 0 }

    var feedImageURLs: [String] { imageURLs ?? [] }

    init(
        id: String? = nil,
        content: String,
        authorId: String,
        authorName: String,
        authorProfileImageURL: String? = nil,
        authorDepartment: String,
        targetDepartment: String?,
        likesCount: Int,
        likes: [String],
        createdAt: Date,
        imageURLs: [String]? = nil,
        parentId: String? = nil,
        threadRootId: String? = nil,
        replyCount: Int? = nil
    ) {
        _id = DocumentID(wrappedValue: id)
        self.content = content
        self.authorId = authorId
        self.authorName = authorName
        self.authorProfileImageURL = authorProfileImageURL
        self.authorDepartment = authorDepartment
        self.targetDepartment = targetDepartment
        self.likesCount = likesCount
        self.likes = likes
        self.createdAt = createdAt
        self.imageURLs = imageURLs
        self.parentId = parentId
        self.threadRootId = threadRootId
        self.replyCount = replyCount
    }

    var isRootPost: Bool { parentId == nil }
}
