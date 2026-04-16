import Foundation
import FirebaseFirestore

struct Chat: Codable, Identifiable {
    @DocumentID var id: String?
    var participants: [String]
    var postId: String?
    var postTitle: String?
    var lastMessage: String
    var lastMessageAt: Date
    var createdAt: Date
}

