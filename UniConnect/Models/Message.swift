import Foundation
import FirebaseFirestore

struct Message: Codable, Identifiable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var imageURL: String?
    var createdAt: Date
    var isRead: Bool
    var sharedType: String?
    var sharedId: String?
    var sharedTitle: String?

    init(
        id: String? = nil,
        senderId: String,
        text: String,
        imageURL: String? = nil,
        createdAt: Date,
        isRead: Bool,
        sharedType: String? = nil,
        sharedId: String? = nil,
        sharedTitle: String? = nil
    ) {
        _id = DocumentID(wrappedValue: id)
        self.senderId = senderId
        self.text = text
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.isRead = isRead
        self.sharedType = sharedType
        self.sharedId = sharedId
        self.sharedTitle = sharedTitle
    }

    var hasImage: Bool {
        guard let url = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !url.isEmpty
    }

    var sharedContent: SharedContentPayload? {
        guard let sharedType,
              let type = SharedContentType(rawValue: sharedType),
              let sharedId,
              let sharedTitle,
              !sharedTitle.isEmpty else { return nil }
        return SharedContentPayload(type: type, contentId: sharedId, title: sharedTitle)
    }

    var hasSharedContent: Bool { sharedContent != nil }
}
