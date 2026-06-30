import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var uid: String
    var displayName: String
    var email: String
    var year: Int
    var department: String
    var bio: String?
    var profileImageURL: String?
    var createdAt: Date
    var role: String?
    var banned: Bool?
    var bannedUntil: Date?

    var isAdmin: Bool { role == "admin" }

    var isBannedNow: Bool {
        guard banned == true else { return false }
        guard let bannedUntil else { return true }
        return bannedUntil > Date()
    }

    enum Department: String, CaseIterable {
        case softversko = "Softversko inzenjerstvo"
        case informacioni = "Informacioni sistemi"
        case racunarske = "Racunarske mreze"
        case poslovnaInformatika = "Poslovna informatika"
    }
}

