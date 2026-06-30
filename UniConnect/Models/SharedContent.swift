import Foundation

enum SharedContentType: String, Codable, CaseIterable {
    case post
    case event
    case feedPost

    var label: String {
        switch self {
        case .post: return "Oglas"
        case .event: return "Događaj"
        case .feedPost: return "Objava"
        }
    }

    var systemImage: String {
        switch self {
        case .post: return "doc.text"
        case .event: return "calendar"
        case .feedPost: return "bubble.left.and.bubble.right"
        }
    }
}

struct SharedContentPayload: Identifiable, Hashable {
    let type: SharedContentType
    let contentId: String
    let title: String

    var id: String { "\(type.rawValue)_\(contentId)" }

    static func post(id: String, title: String) -> SharedContentPayload {
        SharedContentPayload(type: .post, contentId: id, title: title)
    }

    static func event(id: String, title: String) -> SharedContentPayload {
        SharedContentPayload(type: .event, contentId: id, title: title)
    }

    static func feedPost(id: String, title: String) -> SharedContentPayload {
        SharedContentPayload(type: .feedPost, contentId: id, title: title)
    }
}

struct SharedContentNavigation: Hashable {
    let type: SharedContentType
    let contentId: String
}
