import Foundation
import FirebaseFirestore

struct Event: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var category: EventCategory
    var authorId: String
    var authorName: String
    var date: Date
    var location: String
    var latitude: Double?
    var longitude: Double?
    var attendeesCount: Int
    var attendees: [String]
    var createdAt: Date

    /// Nije u Firestore dokumentu — računa se u ViewModel-u.
    var isAttending: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, authorId, authorName, date, location, latitude, longitude, attendeesCount, attendees, createdAt
    }

    enum EventCategory: String, Codable, CaseIterable {
        case akademski = "Akademski"
        case zabava = "Zabava"
        case sport = "Sport"
        case ostalo = "Ostalo"
    }
}

