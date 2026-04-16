import Foundation
import FirebaseFirestore

struct FeedPost: Codable, Identifiable {
    @DocumentID var id: String?
    var content: String
    var authorId: String
    var authorName: String
    var authorDepartment: String
    var targetDepartment: String?
    var likesCount: Int
    var likes: [String]
    var createdAt: Date
}

