import Foundation
import FirebaseFirestore

struct Message: Codable, Identifiable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var imageURL: String?
    var createdAt: Date
    var isRead: Bool

    init(
        id: String? = nil,
        senderId: String,
        text: String,
        imageURL: String? = nil,
        createdAt: Date,
        isRead: Bool
    ) {
        _id = DocumentID(wrappedValue: id)
        self.senderId = senderId
        self.text = text
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.isRead = isRead
    }

    var hasImage: Bool {
        guard let url = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !url.isEmpty
    }
}

