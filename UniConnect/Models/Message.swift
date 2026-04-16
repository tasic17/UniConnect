import Foundation
import FirebaseFirestore

struct Message: Codable, Identifiable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var createdAt: Date
    var isRead: Bool
}

