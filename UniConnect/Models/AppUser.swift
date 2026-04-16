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

    enum Department: String, CaseIterable {
        case softversko = "Softversko inzenjerstvo"
        case informacioni = "Informacioni sistemi"
        case racunarske = "Racunarske mreze"
        case poslovnaInformatika = "Poslovna informatika"
    }
}

