import Foundation
import FirebaseFirestore

enum ReportTargetType: String, Codable, CaseIterable {
    case post
    case event
    case feedPost
    case message
    case user

    var label: String {
        switch self {
        case .post: return "Oglas"
        case .event: return "Događaj"
        case .feedPost: return "Objava"
        case .message: return "Poruka"
        case .user: return "Korisnik"
        }
    }
}

enum ReportStatus: String, Codable {
    case pending
    case resolved
    case dismissed
}

/// `reports/{reportId}`
struct Report: Codable, Identifiable {
    @DocumentID var id: String?
    var reporterId: String
    var targetType: ReportTargetType
    var targetId: String
    var reason: String
    var details: String?
    var targetTitle: String?
    var chatId: String?
    var messageId: String?
    var messageText: String?
    var messageImageURL: String?
    var messageSenderId: String?
    var status: ReportStatus
    var createdAt: Date
    var resolvedAt: Date?
    var resolvedBy: String?

    init(
        id: String? = nil,
        reporterId: String,
        targetType: ReportTargetType,
        targetId: String,
        reason: String,
        details: String? = nil,
        targetTitle: String? = nil,
        chatId: String? = nil,
        messageId: String? = nil,
        messageText: String? = nil,
        messageImageURL: String? = nil,
        messageSenderId: String? = nil,
        status: ReportStatus = .pending,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil,
        resolvedBy: String? = nil
    ) {
        _id = DocumentID(wrappedValue: id)
        self.reporterId = reporterId
        self.targetType = targetType
        self.targetId = targetId
        self.reason = reason
        self.details = details
        self.targetTitle = targetTitle
        self.chatId = chatId
        self.messageId = messageId
        self.messageText = messageText
        self.messageImageURL = messageImageURL
        self.messageSenderId = messageSenderId
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
    }
}

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "Spam"
    case inappropriate = "Neprikladan sadržaj"
    case harassment = "Uznemiravanje"
    case scam = "Prevara / sumnjivo"
    case other = "Ostalo"

    var id: String { rawValue }
}
