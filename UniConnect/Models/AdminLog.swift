import Foundation
import FirebaseFirestore

/// `admin_logs/{logId}`
struct AdminLog: Codable, Identifiable {
    @DocumentID var id: String?
    var adminId: String
    var action: String
    var targetType: String?
    var targetId: String?
    var details: String?
    var createdAt: Date

    init(
        id: String? = nil,
        adminId: String,
        action: String,
        targetType: String? = nil,
        targetId: String? = nil,
        details: String? = nil,
        createdAt: Date = Date()
    ) {
        _id = DocumentID(wrappedValue: id)
        self.adminId = adminId
        self.action = action
        self.targetType = targetType
        self.targetId = targetId
        self.details = details
        self.createdAt = createdAt
    }
}
